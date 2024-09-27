import asyncio
import threading
import sys
from nats.aio.client import Client as NATS
from nats.aio.errors import ErrConnectionClosed, ErrTimeout, ErrNoServers
from queue import Queue, Empty

# Configuration
subscriber_thread = None
message_queue = Queue()

async def subscribe_to_nats(nats_url, topic: str):
    nc = NATS()

    try:
        # Attempt to connect to the NATS server
        await nc.connect(servers=[nats_url])
        print(f"Connected to NATS server at {nats_url}")

    except ErrNoServers as e:
        print(f"Could not connect to NATS server: {e}")
        return

    async def message_handler(msg):
        subject = msg.subject
        reply = msg.reply
        data = msg.data.decode()
        message_queue.put(data)
        print(f"Received a message on '{subject}': {data}")

    # Subscribe to the specified topic with the message handler
    try:
        print(f"Subscribed to topic '{topic}'")
        await nc.subscribe(topic, cb=message_handler)
    except Exception as e:
        print(f"Failed to subscribe to topic '{topic}': {e}")
        await nc.close()
        return

    # Keep the connection alive to listen for messages
    try:
        while True:
            await asyncio.sleep(1)
    except asyncio.CancelledError:
        print("Subscription task cancelled.")
    finally:
        await nc.close()
        print("NATS connection closed.")

def run_nats_subscriber(nats_url, topic):

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        loop.run_until_complete(subscribe_to_nats(nats_url, topic))
    finally:
        loop.close()

def main(nats_url: str, topic: str):
    global subscriber_thread
    if subscriber_thread and subscriber_thread.is_alive():
        subscriber_thread.join(timeout=10)
        # cleanup message queue
        while not message_queue.empty():
            try:
                message_queue.get_nowait()
            except Empty:
                break

    subscriber_thread = threading.Thread(target=run_nats_subscriber, daemon=True, args=(nats_url, topic,))
    subscriber_thread.start()


