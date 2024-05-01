import .main as argoCdOrder
import manifests

import k8s.api.core.v1 as k8core

testApp = argoCdOrder.make({
    Sync = [
        [
            k8core.Namespace {
                metadata.name = "test"
            } 
            k8core.Namespace {
                metadata.name = "test2"
            } 
        ]
        [
            k8core.Namespace {
                metadata.name = "test3"
            } 
            k8core.Namespace {
                metadata.name = "test4"
            } 
        ]
    ]
})


manifests.yaml_stream([
    testApp
])
