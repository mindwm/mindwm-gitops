import pytest
from mindwm import test_namespace
@pytest.mark.dependency(name = "monitoring", scope = 'session')
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
    service = [
       "loki",
       "loki-canary",
       "loki-gateway",
       "loki-headless",
       "loki-memberlist",
       "otel-collector-opentelemetry-collector",
       "tempo",
       "vm-aio-grafana",
       "vm-aio-kube-state-metrics",
       "vm-aio-prometheus-node-exporter",
       "vm-aio-victoria-metrics-operator",
       "vmagent-vm-aio-victoria-metrics-k8s-stack",
       "vmalert-vm-aio-victoria-metrics-k8s-stack",
       "vmalertmanager-vm-aio-victoria-metrics-k8s-stack",
       "vmsingle-vm-aio-victoria-metrics-k8s-stack",
    ]

