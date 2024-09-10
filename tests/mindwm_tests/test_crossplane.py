import pytest
from mindwm import test_namespace
import test_infra

@pytest.mark.k8s_resources
@pytest.mark.dependency(depends=['cluster'], scope = "package")
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

