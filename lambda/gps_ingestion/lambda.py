import base64
import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3


dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

TABLE_NAME = os.environ["DDB_TABLE_NAME"]
BUCKET_NAME = os.environ["S3_BUCKET"]
INGEST_TOKEN = os.environ["INGEST_TOKEN"]
ARCHIVE_PREFIX = os.environ.get("ARCHIVE_PREFIX", "archive/gps")
LATEST_PREFIX = os.environ.get("LATEST_PREFIX", "latest")


def response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json",
            "cache-control": "no-store",
        },
        "body": json.dumps(body, separators=(",", ":")),
    }


def header_value(headers, name):
    if not headers:
        return ""
    wanted = name.lower()
    for key, value in headers.items():
        if key.lower() == wanted:
            return value
    return ""


def parse_body(event):
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    return json.loads(raw)


def parse_timestamp(value):
    if not isinstance(value, str) or not value:
        raise ValueError("timestamp_iso is required")
    normalized = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def decimal_number(payload, field):
    if field not in payload:
        raise ValueError(f"{field} is required")
    return Decimal(str(payload[field]))


def build_item(payload):
    timestamp = parse_timestamp(payload.get("timestamp_iso"))
    vehicle_id = str(payload.get("vehicle_id", "")).strip()
    if not vehicle_id:
        raise ValueError("vehicle_id is required")

    item = {
        "vehicle_id": vehicle_id,
        "timestamp_iso": timestamp.isoformat().replace("+00:00", "Z"),
        "latitude": decimal_number(payload, "latitude"),
        "longitude": decimal_number(payload, "longitude"),
        "speed_kph": Decimal(str(payload.get("speed_kph", 0))),
        "shipment_id": str(payload.get("shipment_id", "")),
        "driver_id": str(payload.get("driver_id", "")),
        "source": str(payload.get("source", "driver-mobile-demo")),
        "received_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "expires_at_epoch": int(timestamp.timestamp()) + (2 * 365 * 24 * 60 * 60),
    }
    return item


def json_safe(value):
    if isinstance(value, Decimal):
        if value % 1 == 0:
            return int(value)
        return float(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def store_item(table, payload):
    item = build_item(payload)
    table.put_item(Item=item)

    archive_key = (
        f"{ARCHIVE_PREFIX}/vehicle_id={item['vehicle_id']}/"
        f"{item['timestamp_iso'].replace(':', '-')}.json"
    )
    latest_key = f"{LATEST_PREFIX}/{item['vehicle_id']}.json"
    body = json.dumps(item, default=json_safe, indent=2).encode("utf-8")

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=archive_key,
        Body=body,
        ContentType="application/json",
        ServerSideEncryption="AES256",
    )
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=latest_key,
        Body=body,
        ContentType="application/json",
        ServerSideEncryption="AES256",
    )
    return item


def lambda_handler(event, context):
    if event.get("requestContext", {}).get("http", {}).get("method") == "GET":
        return response(
            200,
            {
                "service": "scenario-6-gps-ingest",
                "expected_method": "POST",
                "auth_header": "x-ingest-token",
            },
        )

    token = header_value(event.get("headers"), "x-ingest-token")
    if token != INGEST_TOKEN:
        return response(401, {"error": "invalid or missing ingest token"})

    try:
        payload = parse_body(event)
    except json.JSONDecodeError:
        return response(400, {"error": "request body must be valid JSON"})

    if isinstance(payload, dict) and payload.get("simulate_error") is True:
        raise RuntimeError("deliberate alarm test requested by authenticated caller")

    events = payload.get("events") if isinstance(payload, dict) and "events" in payload else payload
    if isinstance(events, dict):
        events = [events]
    if not isinstance(events, list) or not events:
        return response(400, {"error": "send one GPS object or an events array"})
    if len(events) > 25:
        return response(400, {"error": "batch size limit is 25 events"})

    table = dynamodb.Table(TABLE_NAME)
    stored = []
    try:
        for gps_event in events:
            stored.append(store_item(table, gps_event))
    except ValueError as exc:
        return response(400, {"error": str(exc)})

    return response(
        202,
        {
            "stored": len(stored),
            "table": TABLE_NAME,
            "bucket": BUCKET_NAME,
            "vehicles": [item["vehicle_id"] for item in stored],
        },
    )
