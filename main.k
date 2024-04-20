import .argo_cd_order as ArgoCdOrder
import .argocd.schema as argocdSchema
import .helm.chart as charts
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
import .istio as istio
#import argoproj.v1alpha1 as argoproj


ns = "test-namespace"

argoCdOrder = ArgoCdOrder.make({
    PreSync = [
    ]
    Sync = [
        k8core.Namespace {
            metadata.name = istio.system.namespace
        }
        k8core.Namespace {
            metadata.name = istio.gateway.namespace
            metadata.labels = {
                "istio-injection" = "enalbed"
            } 
        }
        argocdSchema.argoHelmRelease({
            namespace = istio.system.namespace,
            name = "istio-base"
            chart = charts.istio_base
            version = istio.version
        }) | {
        spec.ignoreDifferences = [
            {
                group = "admissionregistration.k8s.io"
                kind = "ValidatingWebhookConfiguration"
                name = "istiod-default-validator"
                jsonPointers = ["/webhooks/0/failurePolicy"]
            }
        ]
        } 
        argocdSchema.argoHelmRelease({
            namespace = istio.system.namespace,
            name = "istiod"
            chart = charts.istiod
            version = istio.version
        })
        argocdSchema.argoHelmRelease({
            namespace = istio.gateway.namespace
            name = "gateway"
            chart = charts.istio_gateway
            version = istio.version
        }) 
    ]

    PostSync = []
})

manifests.yaml_stream([
    yaml.decode_all(file.read("manifests/knative-operator.yaml"))
    argoCdOrder
])


