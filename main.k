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
            metadata.name = "test-n"
        }
    ]
    PostSync = []
})

manifests.yaml_stream([
    k8core.Namespace {
        metadata.name = "test-n"
    }
])


