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

