import argo_cd_order as ArgoCdOrder
import .argocd.schema as argocdSchema
import .helm.chart as charts
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
import .istio as istio
import .nats as nats
import knative_operator.v1beta1 as knative
import knative as knativeConfig
import json_merge_patch as p
import .mindwm.context as mindwm_context
import .flux as flux
#import argoproj.v1alpha1 as argoproj


argoCdOrder = ArgoCdOrder.make({
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
            namespace = "nats"
            name = "nats"
            chart = charts.nats
            version = "1.11.1"
            values = {
                config = nats.config
                service = {
                    merge.spec.type = "NodePort"
                    port.cluster.enabled = True
                }
            }
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
        # oci repo
        # https://github.com/argoproj/argo-cd/discussions/11053
        p.merge(argocdSchema.ArgoCdConfigMap, {
            data = {
                repositories = {
                    flux = {
                        url = charts.flux.repoURL
                        type = "helm"
                        name = "flux"
                        enable = "true"
                    }
                }
            }
        })

        # required by redpanda-operator
        # https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/kubernetes/k-deployment-overview/
        argocdSchema.argoHelmRelease({
            namespace = flux.namespace
            name = "flux"
            chart = charts.flux
            version = flux.chart_version
        })

    ] + [
        p.merge(resource, {
            metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
            }
        })
        for resource in yaml.decode_all(file.read("manifests/net-istio.yaml"))
    ] + yaml.decode_all(file.read("manifests/eventing-jsm.yaml")) \
    +  mindwm_context.make(mindwm_context.MindWM) 

    


})

manifests.yaml_stream([
    yaml.decode_all(file.read("manifests/knative-operator.yaml"))
    argoCdOrder
])


