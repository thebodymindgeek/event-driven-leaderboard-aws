import json
import os
import time
from typing import Optional, Dict, Any

import boto3
from botocore.exceptions import ClientError

# -------- AWS clients --------
dynamodb = boto3.client("dynamodb")
sns = boto3.client("sns")

# -------- Env vars --------
NOTIF_TOPIC_ARN = os.environ["NOTIF_TOPIC_ARN"]
PROCESSED_EVENTS_TABLE = os.environ["PROCESSED_EVENTS_TABLE"]
PROGRAM_PROGRESS_TABLE = os.environ["PROGRAM_PROGRESS_TABLE"]
EMPLOYEE_TOTALS_TABLE = os.environ["EMPLOYEE_TOTALS_TABLE"]

DEDUP_TTL_DAYS = int(os.getenv("DEDUP_TTL_DAYS", "14"))

# Milestones for demo emails (edit as you like)
MILESTONE_POINTS = sorted({25, 50, 100, 200, 500})

# If True: send email on failures too (recommended for demo)
EMAIL_ON_FAILURE = os.getenv("EMAIL_ON_FAILURE", "true").lower() in ("1", "true", "yes")


# -------- Helpers --------
def log(stage: str, **fields: Any) -> None:
    print(json.dumps({"stage": stage, **fields}, default=str))


def send_email(subject: str, body: str, attrs: Optional[Dict[str, Any]] = None) -> None:
    attrs = attrs or {}
    sns.publish(
        TopicArn=NOTIF_TOPIC_ARN,
        Subject=subject[:100],  # SNS subject limit
        Message=body,
        MessageAttributes={
            str(k): {"DataType": "String", "StringValue": str(v)}
            for k, v in attrs.items()
        },
    )


def _ttl_epoch_seconds(days: int) -> int:
    return int(time.time()) + days * 24 * 60 * 60


def _get_s(attr_map: Dict[str, Any], key: str) -> str:
    # DynamoDB Stream "NewImage" uses AttributeValue format, e.g. {"S": "value"}
    return attr_map[key]["S"]


def _get_n_int(attr_map: Dict[str, Any], key: str) -> int:
    # Streams use {"N": "5"} as a string
    return int(float(attr_map[key]["N"]))


def _extract_stream_record_from_sqs_body(body: str) -> Dict[str, Any]:
    """
    Each SQS message body is expected to be a JSON DynamoDB Streams record
    (as delivered by EventBridge Pipes from DynamoDB Streams).
    """
    return json.loads(body)


def _crossed_milestone(old_total: int, new_total: int, milestone: int) -> bool:
    return old_total < milestone <= new_total


# -------- Lambda handler --------
def lambda_handler(event, context):
    log(
        "invoke",
        request_id=context.aws_request_id,
        records=len(event.get("Records", [])),
    )

    for record in event.get("Records", []):
        body = record.get("body", "")

        try:
            stream_record = _extract_stream_record_from_sqs_body(body)

            # Only process INSERT events (defensive; you also filtered at the pipe)
            if stream_record.get("eventName") != "INSERT":
                log("skip_non_insert", event_name=stream_record.get("eventName"))
                continue

            new_image = stream_record["dynamodb"]["NewImage"]

            # Parse event fields
            event_id = _get_s(new_image, "event_id")
            employee_id = _get_s(new_image, "employee_id")
            program_id = _get_s(new_image, "program_id")
            activity_type = _get_s(new_image, "activity_type")
            points_awarded = _get_n_int(new_image, "points_awarded")
            ts = _get_s(new_image, "ts")

            log(
                "event_parsed",
                event_id=event_id,
                employee_id=employee_id,
                program_id=program_id,
                activity_type=activity_type,
                points_awarded=points_awarded,
                ts=ts,
            )

            # 1) Idempotency guard: claim event_id once
            try:
                dynamodb.put_item(
                    TableName=PROCESSED_EVENTS_TABLE,
                    Item={
                        "event_id": {"S": event_id},
                        "processed_at": {"S": ts},
                        "ttl": {"N": str(_ttl_epoch_seconds(DEDUP_TTL_DAYS))},
                    },
                    ConditionExpression="attribute_not_exists(event_id)",
                )
                log("dedup_claimed", event_id=event_id)

            except ClientError as e:
                code = e.response.get("Error", {}).get("Code", "")
                if code == "ConditionalCheckFailedException":
                    log("dedup_skip", event_id=event_id)
                    continue
                raise

            # 2) Update ProgramProgress (derived state)
            dynamodb.update_item(
                TableName=PROGRAM_PROGRESS_TABLE,
                Key={
                    "employee_id": {"S": employee_id},
                    "program_id": {"S": program_id},
                },
                UpdateExpression=(
                    "ADD completed_count :one, points_in_program :pts "
                    "SET last_activity_ts = :ts"
                ),
                ExpressionAttributeValues={
                    ":one": {"N": "1"},
                    ":pts": {"N": str(points_awarded)},
                    ":ts": {"S": ts},
                },
            )
            log(
                "program_progress_updated",
                event_id=event_id,
                employee_id=employee_id,
                program_id=program_id,
            )

            # 3) Update EmployeeTotals (derived global totals for leaderboard input)
            # ReturnValues gives us the updated totals so we can trigger milestones correctly.
            resp = dynamodb.update_item(
                TableName=EMPLOYEE_TOTALS_TABLE,
                Key={
                    "employee_id": {"S": employee_id},
                    "scope": {"S": "TOTAL"},
                },
                UpdateExpression=(
                    "ADD total_completed :one, total_points :pts "
                    "SET last_updated = :ts, leaderboard_id = :lid"
                ),
                ExpressionAttributeValues={
                    ":one": {"N": "1"},
                    ":pts": {"N": str(points_awarded)},
                    ":ts": {"S": ts},
                    ":lid": {"S": "GLOBAL"},
                },
                ReturnValues="UPDATED_NEW",
            )

            new_total_points = int(float(resp["Attributes"]["total_points"]["N"]))
            new_total_completed = int(float(resp["Attributes"]["total_completed"]["N"]))

            log(
                "employee_totals_updated",
                event_id=event_id,
                employee_id=employee_id,
                total_points=new_total_points,
                total_completed=new_total_completed,
            )

            # 4) Demo email when crossing milestone thresholds (robust vs equality checks)
            old_total_points = new_total_points - points_awarded

            for milestone in MILESTONE_POINTS:
                if _crossed_milestone(old_total_points, new_total_points, milestone):
                    send_email(
                        subject="EDL Demo: Progress milestone",
                        body=(
                            f"Employee {employee_id} crossed {milestone} points\n"
                            f"Current total: {new_total_points}\n"
                            f"Program: {program_id}\n"
                            f"Event: {event_id}\n"
                            f"Activity: {activity_type} (+{points_awarded})\n"
                            f"Time: {ts}\n"
                        ),
                        attrs={"employee_id": employee_id, "program_id": program_id},
                    )
                    log(
                        "milestone_notified",
                        event_id=event_id,
                        employee_id=employee_id,
                        milestone=milestone,
                        total_points=new_total_points,
                    )

            log("done", event_id=event_id)

        except Exception as e:
            log(
                "failed",
                request_id=context.aws_request_id,
                error=str(e),
                event_id=locals().get("event_id"),
                employee_id=locals().get("employee_id"),
                program_id=locals().get("program_id"),
            )

            if EMAIL_ON_FAILURE:
                try:
                    send_email(
                        subject="EDL Demo: Processor FAILED",
                        body=(
                            f"request_id: {context.aws_request_id}\n"
                            f"event_id: {locals().get('event_id', 'unknown')}\n"
                            f"employee_id: {locals().get('employee_id', 'unknown')}\n"
                            f"program_id: {locals().get('program_id', 'unknown')}\n"
                            f"error: {str(e)}\n"
                        ),
                        attrs={
                            "employee_id": locals().get("employee_id", "unknown"),
                            "program_id": locals().get("program_id", "unknown"),
                        },
                    )
                except Exception as email_err:
                    log("email_failed", request_id=context.aws_request_id, error=str(email_err))

            # Re-raise so SQS retries (and DLQ if configured)
            raise

    return {"statusCode": 200}
