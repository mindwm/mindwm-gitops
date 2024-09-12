import pytest
from mindwm import test_namespace

@pytest.mark.dependency(name = 'istio', scope = 'session')
class Test_Istio(test_namespace):
    namespace = "istio-system"
    deployment = [
        "istiod",
        "istio-ingressgateway",
    ]
    service = [
        "istio-ingressgateway",
        "istiod",
        "knative-local-gateway",
    ]

