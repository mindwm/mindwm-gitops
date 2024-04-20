import .argo_cd_order as ArgoCdOrder
#import yaml
import manifests
import k8s.api.core.v1 as k8core
#import file
#import argoproj.v1alpha1 as argoproj


ns = "test-namespace"

argoCdOrder = ArgoCdOrder.make({
    PreSync = []    
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
    argoCdOrder
    k8core.Namespace {
        metadata.name = "2test-n"
        metadata.annotations = {
            "argocd.argoproj.io/hook" = "Sync"
            "argocd.argoproj.io/sync-wave" = "5"
        }
    }
])


