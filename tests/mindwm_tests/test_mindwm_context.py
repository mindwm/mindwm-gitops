import pytest
from mindwm import test_namespace

context_name = "cyan"

class Test_MindwmContext(test_namespace):
    namespace = f"context-{context_name}"
    deployment = [
        "dead-letter-00001-deployment",
        "io-context-00001-deployment",
        "kafka-cdc-00001-deployment",
        "pong-00001-deployment",
    ]
    services = [
        "io-context",
        "dead-letter",
        "pong",
        "kafka-cdc",
    ] 

#class Test_Nats(object):
#    def test_ns(self, kube):
#        namespaces = kube.get_namespaces()
#        ns = namespaces.get(nats_namespace)
#        assert ns is not None
#
#    @pytest.mark.depends(on=["test_ns"])
#    def test_deployment(self, kube):
#        deployments = kube.get_deployments(namespace=nats_namespace)
#        nats_box = deployments.get(nats_deployment)
#        assert nats_box is not None
#        
#    @pytest.mark.depends(on=["test_ns"])
#    def test_statefulset(self, kube):
#        statefulsets = kube.get_statefulsets(namespace=nats_namespace)
#        nats = statefulsets.get(nats_statefulset)
#        assert nats is not None
#
##
##
##def test_nats_namespace(kube):
##    deployments = kube.get_deployments(namespace=nats_namespace)
##    nats_box = deployments.get(nats_deployment)
##    assert 0 and nats_box is not None
##
