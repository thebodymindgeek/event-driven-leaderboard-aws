import os
import uuid
import random
import json
from datetime import datetime, timezone
import boto3

def log(stage: str, **fields) -> None:
    print(json.dumps({"stage": stage, **fields}, default=str))


dynamodb = boto3.client("dynamodb")

ACTIVITIES_TABLE = os.environ["ACTIVITIES_TABLE"]

EMPLOYEES = [f"E{str(i).zfill(2)}" for i in range(1, 31)] + ["E42", "E88", "E93", "E95", "E99", "E100"]
PROGRAMS = ["P100", "P200", "P400"]
ACTIVITY_TYPES = ["checkin", "movement", "steps"]

def _now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def lambda_handler(event, context):
    log("invoke", count=int((event or {}).get("count", 20)))
    # event may be {} (scheduler / console). That's fine.
    event = event or {}

    # If nothing provided, generate a small burst by default (looks great in demos)
    count = int(event.get("count", 20))

    results = []

    for _ in range(count):
        employee_id = random.choice(EMPLOYEES)
        program_id =  random.choice(PROGRAMS)
        activity_type = random.choice(ACTIVITY_TYPES)
        points = random.randint(1, 25)

        ts = _now_iso()
        event_id = f"evt_sim_{uuid.uuid4().hex[:10]}"
        ts_event = f"{ts}#{event_id}"

        item = {
            "employee_id": {"S": employee_id},
            "ts_event": {"S": ts_event},
            "event_id": {"S": event_id},
            "program_id": {"S": program_id},
            "activity_type": {"S": activity_type},
            "points_awarded": {"N": str(points)},
            "ts": {"S": ts},
        }

        dynamodb.put_item(
            TableName=ACTIVITIES_TABLE,
            Item=item,
            ConditionExpression="attribute_not_exists(employee_id) AND attribute_not_exists(ts_event)",
        )
        log("activity_written",
            event_id=event_id,
            employee_id=employee_id,
            program_id=program_id,
            activity_type=activity_type,
            points_awarded=points,
            ts=ts
        )
        results.append({
            "employee_id": employee_id,
            "program_id": program_id,
            "activity_type": activity_type,
            "points_awarded": points,
            "event_id": event_id,
            "ts": ts,
        })

    return {"ok": True, "inserted": len(results), "events": results}
