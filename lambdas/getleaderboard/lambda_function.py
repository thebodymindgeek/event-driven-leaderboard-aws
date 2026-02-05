import os
import json
from decimal import Decimal
import boto3
from boto3.dynamodb.types import TypeDeserializer

dynamodb = boto3.client("dynamodb")
deser = TypeDeserializer()

TABLE = os.environ["GLOBAL_LEADERBOARD_TABLE"]
LEADERBOARD_ID = os.environ.get("LEADERBOARD_ID", "GLOBAL")


def _av_to_py(item):
    return {k: deser.deserialize(v) for k, v in item.items()}

def _json_safe(x):
    if isinstance(x, list):
        return [_json_safe(i) for i in x]
    if isinstance(x, dict):
        return {k: _json_safe(v) for k, v in x.items()}
    if isinstance(x, Decimal):
        return int(x) if x % 1 == 0 else float(x)
    return x

def lambda_handler(event, context):
    # ---- Handle browser preflight ----
    method = (
        event.get("requestContext", {})
             .get("http", {})
             .get("method", "GET")
    )
    if method == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    # ---- Normal GET ----
    resp = dynamodb.get_item(
        TableName=TABLE,
        Key={
            "leaderboard_id": {"S": LEADERBOARD_ID},
            "as_of": {"S": "LATEST"},
        },
        ConsistentRead=False,
    )

    if "Item" not in resp:
        return {
            "statusCode": 404,
            "headers": {
        "Content-Type": "application/json",
    },            "body": json.dumps({"error": "Leaderboard not found"}),
        }

    item = _av_to_py(resp["Item"])
    return {
        "statusCode": 200,
    "headers": {
        "Content-Type": "application/json",
    },        "body": json.dumps(_json_safe(item)),
    }
