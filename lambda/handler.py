import json
import boto3
import os
import uuid
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    detail = event.get("detail", {})

    incident = {
        "incident_id": str(uuid.uuid4()),
        "logged_at": datetime.utcnow().isoformat(),
        "alarm_name": detail.get("alarmName", "unknown"),
        "new_state": detail.get("state", {}).get("value", "unknown"),
        "previous_state": detail.get("previousState", {}).get("value", "unknown"),
        "reason": detail.get("state", {}).get("reason", ""),
    }

    table.put_item(Item=incident)

    print(f"Logged incident: {incident['incident_id']} for alarm {incident['alarm_name']}")

    return {"statusCode": 200, "body": json.dumps({"logged": incident["incident_id"]})}