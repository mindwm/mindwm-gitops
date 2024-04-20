import argo_cd_order as ArgoCdOrder
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
import argoproj.v1alpha1 as argoproj


ns = "test-namespace"

testApp = ArgoCdOrder.make({
    preSync = [
        k8core.Namespace {
            metadata.name = ns
        }
    ] 
    sync = [
        k8core.ConfigMap {
            metadata = {
                name = "test-configmap"
                namespace = ns
            }
            data = {
                foo = "bar"
            }
        }
    ]
    
    postSync = []

})

manifests.yaml_stream([
    testApp
])


