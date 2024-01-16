import websocket
import json
import threading
import os


def on_message(ws, message):
    global message_buffer, message_complete

    # Assuming the message is a JSON string, parse it into a dictionary
    try:
        response = json.loads(message)
    except json.JSONDecodeError:
        print(f"Error decoding JSON: {message}")
        return

    # Extract completion and stop_reason from the response
    completion = response.get("message", {}).get("completion", "").lstrip()
    stop_reason = response.get("message", {}).get("stop_reason", None)

    # Append to the message buffer
    message_buffer += completion

    # Print the message buffer as it's being built
    print(completion, end="", flush=True)

    # If the message is complete, reset the buffer and set the flag
    if stop_reason:
        message_buffer = ""
        message_complete = True


def on_error(ws, error):
    print(f"Error: {error}")


def on_close(ws, close_status_code, close_msg):
    print("\n### Connection closed ###")


def on_open(ws):
    def run(*args):
        global message_complete
        while True:
            # Wait for the previous message to complete
            while not message_complete:
                pass

            message = input("\nEnter a message (type 'exit' to quit): ")
            if message == "exit":
                break

            message_complete = False
            ws.send(json.dumps({"action": "send", "data": message}))

        ws.close()

    threading.Thread(target=run).start()


if __name__ == "__main__":
    websocket_url = os.environ.get("WEBSOCKET_API_URL")
    ws = websocket.WebSocketApp(
        websocket_url,
        on_open=on_open,
        on_message=on_message,
        on_error=on_error,
        on_close=on_close,
    )

    # Initialize global variables
    message_buffer = ""
    message_complete = True  # Set to True to allow the first message

    ws.run_forever()
