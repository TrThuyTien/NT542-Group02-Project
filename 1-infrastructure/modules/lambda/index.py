import json

def handler(event, context):
    print("Received event:", json.dumps(event))
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Lambda executed successfully",
            "event": event
        })
    }
