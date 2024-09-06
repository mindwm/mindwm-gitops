import pytest
#import asyncio
#import pytest_asyncio
#import nats
from nats.errors import ConnectionClosedError, TimeoutError, NoServersError
from mindwm import test_namespace
import requests    
import json
import os
import time
from opentelemetry.proto.trace.v1 import trace_pb2
from google.protobuf.json_format import ParseDict

nats_namespace = "nats"
nats_statefulset = "nats"
nats_deployment = "nats-box"

payload = {
    "input": "#ping",
    "output": "",
    "ps1": "❯",
    "type": "org.mindwm.v1.iodocument"
}

trace_id = "21781c3be3215d152eb57a6abd8e9d1b"
traceparent = f"00-${trace_id}-33fb3676051a2da3-01"
uuid = "442af213-c860-4535-b639-355f13b2d442"
user = os.getenv("USER")
host = os.getenv("HOST")
context_name = "pink"

ingress_host = os.getenv("INGRESS_HOST", "10.24.142.129")

class Test_PingPong():
    def test_send_ping_context_broker(self):
        url = f'http://{ingress_host}/context-{context_name}/context-broker'

        # Headers as specified in the curl command
        headers = {
            "Host": "broker-ingress.knative-eventing.svc.cluster.local",
            "Content-Type": "application/json",
            "traceparent": traceparent,
            "Ce-specversion": "1.0",
            "Ce-id": uuid,
            "ce-source": f"org.mindwm.{user}.{host}.tmux.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36",
            "ce-subject": "#ping",
            "ce-type": "org.mindwm.v1.iodocument"
        }

        # Send the POST request
        response = requests.post(url, headers=headers, data=json.dumps(payload))

        assert response.status_code == 202, f"Unexpected status code: {response.status_code}"

        print(response.text)  

    @pytest.mark.depends(on=['test_send_ping_context_broker'])
    def test_tracesql(self):
        # TODO(@metacoma) wait for resource
        time.sleep(5)
        url = f"http://tempo.mindwm.local/api/traces/{trace_id}"
        # Perform the GET request
        response = requests.get(url)
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {response.headers}")
        print(f"Response Text: {response.text}")
        tempo_reply = json.loads(response.text)
        trace_data = {
                "resourceSpans": tempo_reply['batches']
        }
        ParseDict(trace_data, trace_pb2.TracesData())



