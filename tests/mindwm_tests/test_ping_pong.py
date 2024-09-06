import pytest
#import asyncio
#import pytest_asyncio
#import nats
from nats.errors import ConnectionClosedError, TimeoutError, NoServersError
from mindwm import test_namespace
import requests    
import json
import os

nats_namespace = "nats"
nats_statefulset = "nats"
nats_deployment = "nats-box"

payload = {
    "input": "#ping",
    "output": "",
    "ps1": "❯",
    "type": "org.mindwm.v1.iodocument"
}

traceparent = "420854416757201cef67e2cd3f44fc42"
trace_id = "442af213-c860-4535-b639-355f13b2d442"
user = "alice"
host = "bob"
context_name = "pink"

ingress_host = os.getenv("INGRESS_HOST", "10.24.142.129")

class Test_PingPong():
    def test_ping_context_broker(self):
        url = f'http://{ingress_host}/context-{context_name}/context-broker'

        # Headers as specified in the curl command
        headers = {
            "Host": "broker-ingress.knative-eventing.svc.cluster.local",
            "Content-Type": "application/json",
            "traceparent": traceparent,
            "Ce-specversion": "1.0",
            "Ce-id": trace_id,
            "ce-source": f"org.mindwm.{user}.{host}.tmux.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36",
            "ce-subject": "#ping",
            "ce-type": "org.mindwm.v1.iodocument"
        }

        # Send the POST request
        response = requests.post(url, headers=headers, data=json.dumps(payload))

        # Assert the response code is as expected (e.g., 200 for success)
        assert response.status_code == 202, f"Unexpected status code: {response.status_code}"

        # Optionally, check the content of the response
        # assert response.json() == {"expected_key": "expected_value"}

        # Print response for debugging
        print(response.text)  


