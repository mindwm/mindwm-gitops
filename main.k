import argo_cd_order as ArgoCdOrder
#import yaml
import manifests
import k8s.api.core.v1 as k8core
#import file
#import argoproj.v1alpha1 as argoproj


ns = "test-namespace"

argoCdOrder = ArgoCdOrder.make({
    preSync = []    
    sync = [
        k8core.Namespace {
            metadata.name = "test-n"
        }
    ]
    postSync = []
})

manifests.yaml_stream([
    argoCdOrder
])


