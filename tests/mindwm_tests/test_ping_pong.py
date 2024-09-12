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
import uuid
import random
from opentelemetry.proto.trace.v1 import trace_pb2
from google.protobuf.json_format import ParseDict
import pprint

nats_namespace = "nats"
nats_statefulset = "nats"
nats_deployment = "nats-box"


payload = {
    "input": "#ping",
    "output": "",
    "ps1": "❯",
    "type": "org.mindwm.v1.iodocument"
}

trace_id = uuid.uuid4().hex
cloudevent_uuid = "442af213-c860-4535-b639-355f13b2d442"
user = os.getenv("USER")
host = os.getenv("HOST")
context_name = "pink"

#ingress_host = os.getenv("INGRESS_HOST", "10.24.142.129")

def get_service_name(span):
    return next(attr.value.string_value for attr in span.resource.attributes if attr.key == "service.name")

def span_by_service_name(traces, service_name):
    for span in traces.resource_spans:
        if get_service_name(span) == service_name:
            return span
    return None


# :(
def parse_resourceSpan(resourceSpan):
    return {
        "service_name": next(attr.value.string_value for attr in resourceSpan.resource.attributes if attr.key == "service.name"),
        "http_code": next(attr.value.string_value for attr in resourceSpan.scope_spans[0].spans[0].attributes if attr.key == "http.status_code"),
        "http_path": next(attr.value.string_value for attr in resourceSpan.scope_spans[0].spans[0].attributes if attr.key == "http.path")
        # context broker
    }

def generate_traceparent(_trace_id):
    span_id = uuid.uuid4().hex[:16]
    traceparent = f"00-{_trace_id}-{span_id}-01"
    return traceparent

@pytest.mark.dependency(name = "ping_pong", depends = ['mindwm_context'], scope = 'session')
class Test_PingPong():
    def get_lb(self, kube):
        services = kube.get_services("istio-system")
        lb_service = services.get("istio-ingressgateway")
        #pprint.pprint(lb_service.status.load_balancer)
        assert lb_service is not None
        lb_ip = lb_service.status().load_balancer.ingress[0].ip
        assert lb_ip is not None
        return lb_ip

        pprint.pprint(service)
        assert False
    def test_send_ping_context_broker(self, kube):
        ingress_host = self.get_lb(kube)
        trace_parent = generate_traceparent(trace_id) 
        url = f"http://{ingress_host}/context-{context_name}/context-broker"
        print(f"Send ping through the context-{context_name} broker {url} traceid: {trace_id}, traceparent: {trace_parent}")

        headers = {
            "Host": "broker-ingress.knative-eventing.svc.cluster.local",
            "Content-Type": "application/json",
            "traceparent": trace_parent,
            "Ce-specversion": "1.0",
            "Ce-id": cloudevent_uuid,
            "ce-source": f"org.mindwm.{user}.{host}.tmux.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36",
            "ce-subject": "#ping",
            "ce-type": "org.mindwm.v1.iodocument"
        }

        response = requests.post(url, headers=headers, data=json.dumps(payload))

        assert response.status_code == 202, f"Unexpected status code: {response.status_code}"

    @pytest.mark.dependency(depends=['test_send_ping_context_broker'])
    def test_tracesql(self,kube):
        # TODO(@metacoma) wait for resource
        #url = f"http://tempo.mindwm.local/api/traces/{trace_id}"
        ingress_host = self.get_lb(kube)
        url = f"http://{ingress_host}/api/traces/{trace_id}"
        headers = {
            "Host": "tempo.mindwm.local"
        }
        print(f"request url {url}")
        time.sleep(5)
        # Perform the GET request
        response = requests.get(url, headers = headers)
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {response.headers}")
        #print(f"Response Text: {response.text}")
        assert response.status_code == 200, f"Response code {response.status_code} != 200"
        tempo_reply = json.loads(response.text)
        trace_data = {
                "resourceSpans": tempo_reply['batches']
        }
        traces = ParseDict(trace_data, trace_pb2.TracesData())

        span = span_by_service_name(traces, "broker-ingress.knative-eventing")
        assert span != None

        scope_spans = span.scope_spans[0]
        sp = parse_resourceSpan(span)
        assert sp['service_name'] == 'broker-ingress.knative-eventing', f"Service name {sp['service_name']} != broker-ingress.knative-eventing"
        assert sp['http_code'] == '202', f"Context broker: {sp['http_code']} != 202"
        assert sp['http_path'] == f"/context-{context_name}/context-broker"
        
#        assert scope_spans.spans[0].name == f"/context-{context_name}/context-broker"
#        assert scope_spans.spans[1].name == f"broker:context-broker.context-pink"
#        assert scope_spans.spans[2].name == f"knative.dev"
#        assert scope_spans.spans[4].name == f"/context-{context_name}/context-broker"
#        assert scope_spans.spans[5].name == f"broker:context-broker.context-pink"
#        assert scope_spans.spans[6].name == f"knative.dev"
#        assert scope_spans.spans[8].name == f"/user-{user}/user-broker"


        span = span_by_service_name(traces, "unknown_service")
        assert span != None
        scope_spans = span.scope_spans[0]
        assert scope_spans.spans[0].name == "knfunc.pong"


        span = span_by_service_name(traces, "jetstream-ch-dispatcher")
        sp = parse_resourceSpan(span)
        assert sp['service_name'] == 'jetstream-ch-dispatcher', f"Service name {sp['service_name']} != jetstream-ch-dispatcher"
        assert sp['http_code'] == '202', f"Context broker: {sp['http_code']} != 202"


