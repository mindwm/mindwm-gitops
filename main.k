import .argo_cd_order as ArgoCdOrder
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
#import argoproj.v1alpha1 as argoproj


ns = "test-namespace"

argoCdOrder = ArgoCdOrder.make({
    PreSync = [
        k8core.Namespace {
            metadata.name = "pre-test-n"
        }
    ]
    Sync = [
        k8core.Namespace {
            metadata.name = "order-test-n"
        }
        k8core.Namespace {
            metadata.name = "order-test-n2"
        }
        k8core.Namespace {
            metadata.name = "order-test-n4"
        }
    ]

    PostSync = []
})

manifests.yaml_stream([
    yaml.decode_all(file.read("manifests/knative-operator.yaml"))
    argoCdOrder
])


