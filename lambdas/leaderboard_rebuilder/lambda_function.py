import os
from datetime import datetime, timezone
import json
import boto3
from boto3.dynamodb.types import TypeDeserializer, TypeSerializer

ddb = boto3.client("dynamodb")
deser = TypeDeserializer()
ser = TypeSerializer()

EMPLOYEE_TOTALS_TABLE = os.environ["EMPLOYEE_TOTALS_TABLE"]
GLOBAL_LEADERBOARD_TABLE = os.environ["GLOBAL_LEADERBOARD_TABLE"]

LEADERBOARD_GSI_NAME = os.getenv("LEADERBOARD_GSI_NAME", "GSI_Leaderboard")
LEADERBOARD_ID = os.getenv("LEADERBOARD_ID", "GLOBAL")
LEADERBOARD_SIZE = int(os.getenv("LEADERBOARD_SIZE", "20"))

def log(stage: str, **fields):
    print(json.dumps({"stage": stage, **fields}, default=str))
 
def av_to_py(item_av: dict) -> dict:
    """Convert DynamoDB AttributeValue map -> normal Python dict."""
    return {k: deser.deserialize(v) for k, v in item_av.items()}

def py_to_av(value):
    """Convert Python value -> DynamoDB AttributeValue."""
    return ser.serialize(value)

def lambda_handler(event, context):
    log("run_start", request_id=context.aws_request_id)
    # 1) Query top N by total_points (desc) via GSI
    resp = ddb.query(
        TableName=EMPLOYEE_TOTALS_TABLE,
        IndexName=LEADERBOARD_GSI_NAME,
        KeyConditionExpression="leaderboard_id = :lid",
        ExpressionAttributeValues={":lid": {"S": LEADERBOARD_ID}},
        ScanIndexForward=False,  # DESC on total_points
        Limit=LEADERBOARD_SIZE,
        ProjectionExpression="employee_id, total_points, total_completed, last_updated",
    )
    rows = [av_to_py(it) for it in resp.get("Items", [])]
    log("candidates_loaded", count=len(rows))

    # Normalize types
    normalized = []
    for it in rows:
        normalized.append({
            "employee_id": str(it.get("employee_id")),
            "total_points": int(it.get("total_points", 0) or 0),
            "total_completed": int(it.get("total_completed", 0) or 0),
            "last_updated": it.get("last_updated"),
        })

    # 2) Optional tie-break refinement:
    # DynamoDB already sorted by total_points; we refine ordering within equal-point groups.
    normalized.sort(key=lambda x: (-x["total_points"], -x["total_completed"], x["employee_id"]))

    # 3) Add rank
    top = []
    for rank, it in enumerate(normalized, start=1):
        top.append({
            "rank": rank,
            "employee_id": it["employee_id"],
            "total_points": it["total_points"],
            "total_completed": it["total_completed"],
            "last_updated": it.get("last_updated"),
        })
    log("leaderboard_computed", top_size=str(len(top)))
    generated_at = datetime.now(timezone.utc).isoformat()

    # 4) Write snapshot for dashboard reads
    ddb.put_item(
        TableName=GLOBAL_LEADERBOARD_TABLE,
        Item={
            "leaderboard_id": {"S": LEADERBOARD_ID},
            "as_of": {"S": "LATEST"},
            "generated_at": {"S": generated_at},
            "top_size": {"N": str(len(top))},
            "top": py_to_av(top),
        },
    )
    log("leaderboard_written", leaderboard_id="GLOBAL", as_of="LATEST", generated_at=generated_at)

    return {"ok": True, "generated_at": generated_at, "top_size": len(top)}
