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
    #statefulset = [ 
        #"kafka-broker-dispatcher",
        #"kafka-channel-dispatcher",
          #"kafka-source-dispatcher"
    #]
    service = [
        "broker-filter",
        "broker-ingress",
        "eventing-webhook",
        "imc-dispatcher",
        "inmemorychannel-webhook",
        "jetstream-ch-dispatcher",
        "job-sink",
        "kafka-broker-ingress",
        "kafka-channel-ingress",
        "kafka-webhook-eventing",
        "nats-webhook",
    ]
