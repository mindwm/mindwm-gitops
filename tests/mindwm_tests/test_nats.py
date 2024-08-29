import pytest
from mindwm import test_namespace

nats_namespace = "nats"
nats_statefulset = "nats"
nats_deployment = "nats-box"

class Test_Nats(test_namespace):
    namespace = "nats"
    deployment = [ "nats-box" ]

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
