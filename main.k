import .argo_cd_order as ArgoCdOrder
import .argocd.schema as argocdSchema
import .helm.chart as charts
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
import .istio as istio
import knative_operator.v1beta1 as knative
import knative as knativeConfig
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
        }
        k8core.Namespace {
            metadata.name = knativeConfig.serving.namespace
            metadata.labels = {
                "istio-injection" = "enalbed"
            } 
        }
        k8core.Namespace {
            metadata.name = knativeConfig.eventing.namespace
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
        argocdSchema.argoHelmRelease({
            namespace = "cert-manager"
            name = "cert-manager"
            chart = charts.cert_manager
            version = "1.14.4"
            values = {
                installCRDs = True
            }
        })
        argocdSchema.argoHelmRelease({
            namespace = "redpanda"
            name = "redpanda-operator"
            chart = charts.redpanda_operator
            version = "0.4.20"
        })

        knative.KnativeServing {
            metadata.name = "knative-serving"
            metadata.namespace = knativeConfig.serving.namespace
            metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
            }
            spec.config.istio = {
                "local-gateway.${istio.gateway.namespace}.knative-local-gateway" = "knative-local-gateway.${istio.system.namespace}.svc.cluster.local"
            } 
        } 

        knative.KnativeEventing {
            metadata.name = "knative-eventing"
            metadata.namespace = knativeConfig.eventing.namespace
            metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
            }

        } 

    ] #+ yaml.decode_all(file.read("manifests/net-istio.yaml"))

    PostSync = []
})

manifests.yaml_stream([
    yaml.decode_all(file.read("manifests/knative-operator.yaml"))
    argoCdOrder
])


