import pytest
from mindwm import test_namespace

class Test_Redpanda(test_namespace):
    namespace = "redpanda"
    deployment = [
        "neo4j-cdc-console",
        "redpanda-operator"
    ]
    statefulset = [ "neo4j-cdc" ]
