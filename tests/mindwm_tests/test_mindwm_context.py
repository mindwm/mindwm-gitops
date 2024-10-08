import pytest
from object_mindwm_context import MindwmContext
from kubetest.condition import Condition
from kubetest.utils import wait_for_condition
from kubetest.objects import Namespace
import kubernetes_utils
from test_redpanda import Test_Redpanda

test_context_name = "pink"
DEFAULT_TIMEOUT = 60

class TestHellWorld():
    def test_hello(self):
        print("hello")

#@pytest.mark.dependency(depends=["redpanda", 'crossplane', 'istio', 'knative_eventing', 'knative_serving', 'monitoring', 'nats2'], scope = 'session')
class Test_MindwmContext():
    ctx = MindwmContext(test_context_name)
    @pytest.mark.dependency(name = "test_crd_status", depends = ['TestHelloWorld::test_hello', 'deployment', 'statefulset', 'service'], scope = "session")
    def test_crd_status(self, kube):
        self.ctx.create()
        wait_for_condition(Condition("wait for context is ready", self.ctx.status), 60)
    @pytest.mark.dependency(name = "context_namespace", on=["crd_status"], scope = 'session')
    def test_context_namespace(self, kube):
        wait_for_condition(Condition("wait for namespace", kubernetes_utils.wait_for_namespace, kube, "context-pink"), DEFAULT_TIMEOUT)
        wait_for_condition(Condition("wait for namespace is ready", kubernetes_utils.wait_for_namespace_is_ready, kube, "context-pink"), DEFAULT_TIMEOUT)

    @pytest.mark.dependency(name = "context_broker", on=["context_namespace"], scope = 'session')
    def test_context_broker(self, kube):
        wait_for_condition(Condition("wait for context broker", kubernetes_utils.wait_for_broker, kube, "context-broker", "context-pink"), DEFAULT_TIMEOUT)
        wait_for_condition(Condition("wait for context broker is ready", kubernetes_utils.wait_for_broker_is_ready, kube, "context-broker", "context-pink"), DEFAULT_TIMEOUT)

    @pytest.mark.dependency(name = "kafka_source", on=["context_broker"], scope = 'session')
    def test_kafka_source(self, kube):
        wait_for_condition(Condition("wait for kafkaSource resource", kubernetes_utils.wait_for_kafka_source, kube,f"context-{self.ctx.name}-cdc-kafkasource", self.ctx.context_namespace), DEFAULT_TIMEOUT)
        wait_for_condition(Condition("wait for kafkaSource resource", kubernetes_utils.wait_for_kafka_source_is_ready, kube,f"context-{self.ctx.name}-cdc-kafkasource", self.ctx.context_namespace), DEFAULT_TIMEOUT)

    def wait_for_ksvc(self, kube, function_name):
        wait_for_condition(Condition(f"wait for ksvc {{ function_name }}", 
            kubernetes_utils.wait_for_resource, 
            kube, 
            {
                'apiVersion': 'serving.knative.dev/v1',
                'kind': 'Service',
                'name': function_name
            }, 
            self.ctx.context_namespace),
        DEFAULT_TIMEOUT)

    def wait_for_ksvc_is_ready(self, kube, function_name):
        wait_for_condition(Condition(f"wait for ksvc {{ function_name }} is ready", 
            kubernetes_utils.wait_for_resource, 
            kube, 
            {
                'apiVersion': 'serving.knative.dev/v1',
                'kind': 'Service',
                'name': function_name,
                'readyConditions': [ 
                    'RoutesReady',
                    'ConfigurationsReady',
                    'Ready'
                ]
            }, 
            self.ctx.context_namespace),
        DEFAULT_TIMEOUT)


    def wait_for_function_deployment_is_ready(self, kube, function_name):
        wait_for_condition(Condition(f"wait for function {{ function_name }} deployment is ready", 
            kubernetes_utils.wait_for_function_deployment, 
            kube, 
            function_name,
            self.ctx.context_namespace),
        DEFAULT_TIMEOUT)


    @pytest.mark.dependency(name = "pong_function", on=["kafka_source"], scope = 'session')
    def test_pong_function(self, kube):
        self.wait_for_ksvc(kube, "pong")
        self.wait_for_ksvc_is_ready(kube, "pong")
        self.wait_for_function_deployment_is_ready(kube, "pong")

    @pytest.mark.dependency(name = "kafka_cdc_function", on=["kafka_source"], scope = 'session')
    def test_kafka_cdc_function(self, kube):
        self.wait_for_ksvc(kube, "kafka-cdc")
        self.wait_for_ksvc_is_ready(kube, "kafka-cdc")
        self.wait_for_function_deployment_is_ready(kube, "kafka-cdc")

    @pytest.mark.dependency(name = "iocontext_function", on=["kafka_source"], scope = 'session')
    def test_iocontext_function(self, kube):
        self.wait_for_ksvc(kube, "iocontext")
        self.wait_for_ksvc_is_ready(kube, "iocontext")
        self.wait_for_function_deployment_is_ready(kube, "iocontext")
