import pytest
from object_mindwm_context import MindwmContext
from kubetest.condition import Condition
from kubetest.utils import wait_for_condition
from kubetest.objects import Namespace
import kubernetes_utils

test_context_name = "pink"

class Test_MindwContext():
    @pytest.mark.dependency(name = "test_crd_status")
    def test_crd_status(self, kube):
        self.ctx = MindwmContext(test_context_name)
        self.ctx.create()
        wait_for_condition(Condition("wait for context is ready", self.ctx.status), 60)
    @pytest.mark.dependency(name = "context_namespace", on=["crd_status"])
    def test_context_namespace(self, kube):
        wait_for_condition(Condition("wait for namespace", kubernetes_utils.wait_for_namespace, kube, "context-pink"), 5)
        wait_for_condition(Condition("wait for namespace is ready", kubernetes_utils.wait_for_namespace_is_ready, kube, "context-pink"), 5)

    @pytest.mark.dependency(name = "context_broker", on=["context_namespace"])
    def test_context_broker(self, kube):
        wait_for_condition(Condition("wait for context broker", kubernetes_utils.wait_for_broker, kube, "context-broker", "context-pink"), 5)
        #wait_for_condition(Condition("wait for context broker is ready", kubernetes_utils.wait_for_broker_is_ready, kube, "context-broker", "context-pink"), 5)
        


