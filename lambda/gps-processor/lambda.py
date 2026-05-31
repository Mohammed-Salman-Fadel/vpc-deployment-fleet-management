import json
import random
import boto3
from datetime import datetime

s3 = boto3.client("s3")

BUCKET_NAME = "mersin-logistics-gps"
PREFIX = "gps-data/"

TRUCKS = {
    "TR-102": {
        "shipment_id": "SHP-2026-001",
        "route": "Ankara-Konya-Mersin",
        "destination": "Mersin Warehouse",
        "locations": [
            {"name": "Ankara", "lat": 39.9334, "lon": 32.8597},
            {"name": "Konya", "lat": 37.8746, "lon": 32.4932},
            {"name": "Mersin", "lat": 36.8121, "lon": 34.6415}
        ]
    },
    "TR-145": {
        "shipment_id": "SHP-2026-014",
        "route": "Istanbul-Edirne-Bulgaria-Romania",
        "destination": "Bucharest Romania",
        "locations": [
            {"name": "Istanbul", "lat": 41.0082, "lon": 28.9784},
            {"name": "Kapikule Border Gate", "lat": 41.7167, "lon": 26.3500},
            {"name": "Bucharest", "lat": 44.4268, "lon": 26.1025}
        ]
    },
    "TR-188": {
        "shipment_id": "SHP-2026-022",
        "route": "Gaziantep-Adana-Mersin Port",
        "destination": "Mersin Port",
        "locations": [
            {"name": "Gaziantep", "lat": 37.0662, "lon": 37.3833},
            {"name": "Adana", "lat": 37.0000, "lon": 35.3213},
            {"name": "Mersin Port", "lat": 36.8000, "lon": 34.6333}
        ]
    }
}

def make_response(status_code, payload):
    return {
        "statusCode": status_code,
        "isBase64Encoded": False,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(payload)
    }

def create_event(truck_id):
    truck = TRUCKS.get(truck_id, TRUCKS["TR-102"])
    location = random.choice(truck["locations"])

    data = {
        "truck_id": truck_id,
        "shipment_id": truck["shipment_id"],
        "status": random.choice(["In Transit", "Waiting at Customs", "Arrived at Warehouse"]),
        "current_location": location["name"],
        "latitude": location["lat"],
        "longitude": location["lon"],
        "route": truck["route"],
        "destination": truck["destination"],
        "eta": random.choice(["2 hours", "5 hours", "11 hours", "Arrived"]),
        "timestamp": datetime.utcnow().isoformat()
    }

    key = f"{PREFIX}{truck_id}-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}.json"

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=json.dumps(data),
        ContentType="application/json"
    )

    return {
        "message": "GPS event stored successfully",
        "s3_key": key,
        "data": data
    }

def get_latest_event(truck_id):
    response = s3.list_objects_v2(
        Bucket=BUCKET_NAME,
        Prefix=f"{PREFIX}{truck_id}-"
    )

    if "Contents" not in response or len(response["Contents"]) == 0:
        return {
            "message": "No GPS data found",
            "truck_id": truck_id,
            "data": None
        }

    latest = max(response["Contents"], key=lambda item: item["LastModified"])
    obj = s3.get_object(Bucket=BUCKET_NAME, Key=latest["Key"])
    data = json.loads(obj["Body"].read().decode("utf-8"))

    return {
        "message": "Latest GPS event retrieved successfully",
        "s3_key": latest["Key"],
        "data": data
    }

def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    if method == "OPTIONS":
        return make_response(200, {"message": "CORS OK"})

    query = event.get("queryStringParameters") or {}
    truck_id = query.get("truck_id", "TR-102")

    if method == "POST":
        payload = create_event(truck_id)
        return make_response(200, payload)

    if method == "GET":
        payload = get_latest_event(truck_id)
        return make_response(200, payload)

    return make_response(405, {"message": "Method not allowed"})