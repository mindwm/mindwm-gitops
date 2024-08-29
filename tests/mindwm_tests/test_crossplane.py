import pytest
from mindwm import test_namespace

class Test_Crossplane(test_namespace):
    namespace = "crossplane-system"
    deployment = [
        "crossplane",
    ]

