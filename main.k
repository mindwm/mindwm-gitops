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
import .flux as flux
import .redpanda.config as redpanda_config
import .redpanda.schema as RedPandaSchema
import neo4j.schema as Neo4jSchema
import .crossplane.function as CrossPlaneFunction
import .crossplane.provider as CrossPlaneProvider
import .config as config
import .crossplane.xrd_kcl_function as XrdKclFunction
import json
#import argoproj.v1alpha1 as argoproj


mindwm_app = ArgoCdOrder.make({
    Sync = [
        [
            k8core.Namespace {
                metadata.name = redpanda_config.redpanda.namespace
            }
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
                namespace = "cert-manager"
                name = "cert-manager"
                chart = charts.cert_manager
                version = "1.14.4"
                values = {
                    installCRDs = True
                }
            }) | {
            spec.ignoreDifferences = [
                    {
                        group = "apiextensions.k8s.io"
                        kind = "CustomResourceDefinition"
                        name = "certificaterequests.cert-manager.io"
                        jsonPointers = ["/status"]
                    }
                    {
                        group = "apiextensions.k8s.io"
                        kind = "CustomResourceDefinition"
                        name = "certificates.cert-manager.io"
                        jsonPointers = ["/status"]
                    }
                    {
                        group = "apiextensions.k8s.io"
                        kind = "CustomResourceDefinition"
                        name = "challenges.acme.cert-manager.io"
                        jsonPointers = ["/status"]
                    }
                    {
                        group = "apiextensions.k8s.io"
                        kind = "CustomResourceDefinition"
                        name = "clusterissuers.cert-manager.io"
                        jsonPointers = ["/status"]
                    }
                    {
                        group = "apiextensions.k8s.io"
                        kind = "CustomResourceDefinition"
                        name = "issuers.cert-manager.io"
                        jsonPointers = ["/status"]
                    }
                    {
                        group = "apiextensions.k8s.io"
                        kind = "CustomResourceDefinition"
                        name = "orders.acme.cert-manager.io"
                        jsonPointers = ["/status"]
                    }

                ]
            }

            argocdSchema.argoHelmRelease({
                namespace = nats.nats_namespace
                name = nats.nats_release_name
                chart = charts.nats
                version = "1.1.11"
                values = {
                    config = nats.config
                    service = {
                        merge.spec.type = "NodePort"
                        port.cluster.enabled = True
                    }
                }
            })

            argocdSchema.argoHelmRelease({
                namespace = config.config.crossplane.namespace
                name = "crossplane"
                chart = charts.crossplane
                version = "1.15.2"
#                values = {
#                    provider.packages = [
#                        "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.13.0"
#                        "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.18.1"
#                   ]
#                   #configuration.packages = [
#                   #     "xpkg.upbound.io/crossplane-contrib/function-kcl:v0.7.0"
#                   #]
#
#                }
            })

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
        ]
        [


            argocdSchema.argoHelmRelease({
                namespace = istio.gateway.namespace
                name = "gateway"
                chart = charts.istio_gateway
                version = istio.version
            })

            # required by redpanda-operator
            # https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/kubernetes/k-deployment-overview/
            argocdSchema.argoHelmRelease({
                namespace = flux.namespace
                name = "flux"
                chart = charts.flux
                version = flux.chart_version
            })

        ] + yaml.decode_all(file.read("redpanda/crds.yaml")) \
        + yaml.decode_all(file.read("redpanda/fix_cluster_role_binding.yaml")) \
        + yaml.decode_all(file.read("manifests/knative-operator.yaml"))
        [
            argocdSchema.argoHelmRelease({
                namespace = redpanda_config.redpanda.namespace
                name = "redpanda-operator"
                chart = charts.redpanda_operator
                version = "0.4.21"
            })

            RedPandaSchema.makeKafkaCluster(config.kafka.cluster_name)
            knative.KnativeServing {
                metadata.name = "knative-serving"
                metadata.namespace = knativeConfig.serving.namespace
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
                spec = {
                    config = {
                        istio = {
                            "local-gateways" = yaml.encode([{
                                name = "knative-local-gateway"    
                                namespace = "knative-serving"
                                service = "knative-local-gateway.istio-system.svc.cluster.local"
                            }])
                            "external-gateways" = yaml.encode([{
                                name = "knative-ingress-gateway"
                                namespace = "knative-serving"
                                service = "gateway.istio-ingress.svc.cluster.local"
                            }])

                        } 
                    }
                }
                #"spec.config.istio.local-gateways" = {
                #    "local-gateway.${istio.gateway.namespace}.knative-local-gateway" = "knative-local-gateway.${istio.system.namespace}.svc.cluster.local"
                #}
            }

            knative.KnativeEventing {
                metadata.name = "knative-eventing"
                metadata.namespace = knativeConfig.eventing.namespace
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            }

            k8core.ConfigMap {
                metadata.name = "config-nats"
                metadata.namespace = knativeConfig.eventing.namespace
                data = {
                   "eventing-nats" = yaml.encode({
                        url = "nats://${nats.nats_user}:${nats.nats_password}@${nats.nats_release_name}.${nats.nats_namespace}:${nats.nats_port}"
                        connOpts = {
                            retryOnFailedConnect = True
                            maxReconnects = 50
                            reconnectWait = 2000
                            reconnectJitterMilliseconds = 100
                            reconnectJitterTLSMilliseconds = 1000
                        } 
                   })
                } 

            }

            CrossPlaneFunction.makeCrossPlaneFunction(CrossPlaneFunction.kcl)
            CrossPlaneFunction.makeCrossPlaneFunction(CrossPlaneFunction.auto_ready)
            CrossPlaneProvider.makeCrossPlaneProvider(CrossPlaneProvider.kubernetes)


        ]
        CrossPlaneProvider.makeCrossPlaneProviderHelm(CrossPlaneProvider.helm)
        [
            p.merge(resource, {
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            })
            for resource in yaml.decode_all(file.read("manifests/net-istio.yaml"))


        ]
        [
            {
                apiVersion = "kubernetes.crossplane.io/v1alpha1"
                kind = "ProviderConfig"
                metadata.name = "default"
                spec.credentials.source = "InjectedIdentity"
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            }
            {
                apiVersion = "helm.crossplane.io/v1alpha1"
                kind = "ProviderConfig"
                metadata.name = "default"
                spec.credentials.source = "InjectedIdentity"
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            }
        ]
        yaml.decode_all(file.read("manifests/knative/eventing-kafka-controller.yaml"))
        yaml.decode_all(file.read("manifests/knative/eventing-kafka-source.yaml"))
        yaml.decode_all(file.read("manifests/eventing-jsm.yaml"))
        yaml.decode_all(file.read("manifests/mdns.yaml"))

        [
            p.merge(resource, {
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            })
            for resource in XrdKclFunction.makeContextXR() + XrdKclFunction.makeUserXR() + XrdKclFunction.makeHostXR()
        ]

    ]

})

manifests.yaml_stream([
    mindwm_app
])


