import pytest
from mindwm import test_namespace

class Test_Monitoring(test_namespace):
    namespace = "monitoring"
    deployment = [
        "loki-gateway",
        "otel-collector-opentelemetry-collector",
        "vm-aio-grafana",
        "vm-aio-kube-state-metrics",
        "vmagent-vm-aio-victoria-metrics-k8s-stack",
        "vmalert-vm-aio-victoria-metrics-k8s-stack",
        "vmsingle-vm-aio-victoria-metrics-k8s-stack"
    ]
    statefulset = [ 
        "tempo",
        "loki",
        "vmalertmanager-vm-aio-victoria-metrics-k8s-stack"
    ]

