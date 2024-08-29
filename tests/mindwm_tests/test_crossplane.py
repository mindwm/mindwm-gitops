import pytest
from mindwm import test_namespace

class Test_Crossplane(test_namespace):
    namespace = "crossplane-system"
    deployment = [
        "crossplane",
    ]
    service = [
        "crossplane-webhooks",
        "function-auto-ready",
        "function-kcl",
        "provider-helm",
        "provider-kubernetes",
    ]

