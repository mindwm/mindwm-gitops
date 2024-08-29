import pytest
from mindwm import test_namespace

class Test_KnativeEventing(test_namespace):
    namespace = "knative-eventing"
    deployment = [
        "eventing-controller",
        "eventing-webhook",
        "imc-controller",
        "jetstream-ch-controller",
        "kafka-controller"
    ]
    statefulset = [ 
        #"kafka-broker-dispatcher",
        #"kafka-channel-dispatcher",
        "kafka-source-dispatcher"
    ]
