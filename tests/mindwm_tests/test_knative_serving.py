import pytest
from mindwm import test_namespace

class Test_KnativeEventing(test_namespace):
    namespace = "knative-serving"
    deployment = [
        "activator",
        "autoscaler",
        "autoscaler-hpa",
        "controller",
        "net-istio-controller",
        "webhook",
        "net-istio-webhook"
    ]
    service = [
        "activator-service",
        "autoscaler",
        "autoscaler-bucket-00-of-01",
        "autoscaler-hpa",
        "controller",
        "default-domain-service",
        "net-istio-webhook",
        "webhook",
    ]

