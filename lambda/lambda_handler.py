import json
import boto3
import os
import logging
import socket
import requests

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

# Environment variables
api_gateway_id = os.environ.get("API_GATEWAY_ID")
region = os.environ.get("REGION")
stage = os.environ.get("STAGE")


def handler(event, context):
    connection_id = event["requestContext"]["connectionId"]
    user_input = json.loads(event["body"])["data"]
    logger.info(f"Received data: {user_input}, Connection ID: {connection_id}")

    # Invoke the Bedrock model and send responses as they are received
    invoke_bedrock_model("anthropic.claude-v2", user_input, connection_id)

    return {"statusCode": 200}


def invoke_bedrock_model(model_id, input_data, connection_id):
    client = boto3.client("bedrock-runtime")
    body = json.dumps(
        {
            "prompt": "\n\nHuman: " + input_data + "\n\nAssistant:",
            "max_tokens_to_sample": 512,
        }
    )
    try:
        response = client.invoke_model_with_response_stream(modelId=model_id, body=body)
        # Process the response stream and send each chunk
        stream = response.get("body")
        if stream:
            for event in stream:
                chunk = event.get("chunk")
                if chunk:
                    message = json.loads(chunk.get("bytes").decode())
                    logger.debug(
                        f"Received chunk: {message}"
                    )  # Debug log for each chunk
                    send_to_websocket(connection_id, message)
    except Exception as e:
        logger.error(f"Error in invoking the Bedrock model: {str(e)}")


def check_dns_resolution(host_name):
    try:
        # 호스트 이름을 해결하려고 시도
        resolved_ip = socket.gethostbyname(host_name)

        # 성공적으로 해결되었을 경우 IP 주소 출력
        logger.info(f"DNS resolution successful. IP address: {resolved_ip}")

        return True
    except socket.gaierror:
        # DNS 해결 실패 시 에러 메시지 출력
        logger.info("DNS resolution failed. Check your DNS settings.")
        return False


def test_http_request():
    try:
        response = requests.get("https://www.google.com")
        if response.status_code == 200:
            logger.info("HTTP request successful.")
        else:
            logger.error(
                f"HTTP request failed with status code: {response.status_code}"
            )
    except requests.exceptions.RequestException as e:
        logger.error(f"HTTP request failed: {str(e)}")


def send_to_websocket(connection_id, message):
    client = boto3.client(
        "apigatewaymanagementapi",
        endpoint_url=f"https://{api_gateway_id}.execute-api.{region}.amazonaws.com/{stage}",
    )
    try:
        client.post_to_connection(
            ConnectionId=connection_id, Data=json.dumps({"message": message})
        )
        logger.info(f"Message sent to WebSocket connection ID: {connection_id}")
    except client.exceptions.GoneException:
        logger.warning(
            f"Connection ID {connection_id} is gone. Unable to send message."
        )
    except Exception as e:
        logger.error(f"Failed to send message to WebSocket: {str(e)}")
