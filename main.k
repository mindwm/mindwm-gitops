import argo_cd_order as ArgoCdOrder
import .argocd.schema as argocdSchema
import .helm.chart as charts
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
import .nats as nats
import knative_operator.v1beta1 as knative
import json_merge_patch as p
#import .flux as flux
import .redpanda.config as redpanda_config
import .redpanda.schema as RedPandaSchema
import .mindwm_crossplane.function as CrossPlaneFunction
import .mindwm_crossplane.provider as CrossPlaneProvider
import .config as config
import .mindwm_crossplane.xrd_kcl_function as XrdKclFunction
import util
#import argoproj.v1alpha1 as argoproj
import istio.v1alpha3.networking_istio_io_v1alpha3_gateway as istio_gateway
import istio.v1alpha3.networking_istio_io_v1alpha3_virtual_service as istio_virtual_service
import crossplane_provider_http.v1alpha1.http_crossplane_io_v1alpha1_provider_config as ProviderConfigHttp
import crossplane.v1 as crossplane



mindwm_app = ArgoCdOrder.make({
    Sync = [
        [
            k8core.Namespace {
                metadata.name = redpanda_config.redpanda.namespace
            }
            k8core.Namespace {
                metadata.name = config.istio.system.namespace
            }
            k8core.Namespace {
                metadata.name = config.istio.gateway.namespace
            }
            k8core.Namespace {
                metadata.name = config.knative.serving.namespace
            }
            k8core.Namespace {
                metadata.name = config.knative.eventing.namespace
            }

            argocdSchema.argoHelmRelease({
                namespace = config.cert_manager.namespace
                name = "cert-manager"
                chart = charts.cert_manager
                version = config.cert_manager.helm_chart_version
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
                namespace = config.istio.system.namespace,
                name = "istio-base"
                chart = charts.istio_base
                version = config.istio.version
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
                namespace = config.istio.system.namespace,
                name = "istiod"
                chart = charts.istiod
                version = config.istio.version
                values = {
                    pilot.resources.requests.cpu = config.istio.pilot.cpu_req
                }

            })
        ]
        [

            argocdSchema.argoHelmRelease({
                namespace = nats.nats_namespace
                name = nats.nats_release_name
                chart = charts.nats
                version = "1.3.6"
                values = {
                    config = nats.config
                    service = {
                        merge.spec.type = "LoadBalancer"
                        port.cluster.enabled = True
                        port.cluster.targetPort = nats.nats_port
                        port.cluster.port = nats.nats_port

                    }
                }
            })

            argocdSchema.argoHelmRelease({
                namespace = config.monitoring.namespace
                name = config.monitoring.loki.release_name
                chart = charts.loki
                version = "6.29.0"
                values = util.yaml_file_merge("observability/loki.yaml", {
                })
            })

            argocdSchema.argoHelmRelease({
                namespace = config.zot.namespace
                name = config.zot.release_name
                chart = charts.zot_registry
                version = config.zot.chart_version
                values = {
                  service.type = "NodePort"
                  service.nodePort = "30001"
                }
            })

            argocdSchema.argoHelmRelease({
                namespace = config.monitoring.namespace
                name = config.monitoring.otel_collector.release_name
                chart = charts.otel_collector
                version = "0.122.5"
                values = util.yaml_file_merge("observability/otel-collector.yaml", {
                    config.exporters.otlphttp.endpoint = config.monitoring.loki_endpoint()
                })
            })

            argocdSchema.argoHelmRelease({
                namespace = config.monitoring.namespace
                name = config.monitoring.tempo.release_name
                chart = charts.tempo
                version = "1.21.1"
                values = {
                    tempo.receivers.zipkin.endpoint = "0.0.0.0:9411"
                    tempo.metricsGenerator = {
                        enabled = True
                        remoteWriteUrl = config.monitoring.prometheus_endpoint() + "/api/v1/write"
                    }
                }
            })
            p.merge(argocdSchema.argoHelmRelease({
                namespace = config.monitoring.namespace
                name = config.monitoring.victoria_metrics.release_name
                chart = charts.victoria_metrics
                version = "0.25.10"
                values = util.yaml_file_merge("observability/victoria_metrics.yaml", {
                })
            }), {
              spec.syncPolicy.syncOptions = [ "ServerSideApply=true", "CreateNamespace=true" ],
              spec.ignoreDifferences = [
                  {
                      group = ""
                      kind = "Secret"
                      name = config.monitoring.victoria_metrics.release_name + "-validation",
                      jsonPointers = ["/data"]
                  },
                  {
                      group = "admissionregistration.k8s.io"
                      kind = "ValidatingWebhookConfiguration"
                      name = config.monitoring.victoria_metrics.release_name + "-admission",
                      jsonPointers = [".webhooks[]?.clientConfig.caBundle"]
                  }
              ]
            })

            argocdSchema.argoHelmRelease({
                namespace = config.monitoring.namespace
                name = config.monitoring.promtail.release_name
                chart = charts.promtail
                version = config.monitoring.promtail.chart_version
                values = {
                  config.clients = [{
                    url = "http://${config.monitoring.loki.release_name}.${config.monitoring.namespace}:3100/loki/api/v1/push"
                    tenant_id = 1
                  }]
                }
            })



            argocdSchema.argoHelmRelease({
                namespace = config.config.crossplane.namespace
                name = "crossplane"
                chart = charts.crossplane
                version = "1.19.1"
            })

        ]
        [



            # required by redpanda-operator
            # https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/kubernetes/k-deployment-overview/
            # argocdSchema.argoHelmRelease({
            #     namespace = flux.namespace
            #     name = "flux"
            #     chart = charts.flux
            #     version = flux.chart_version
            # })

        ] + yaml.decode_all(file.read("redpanda/crd/cluster.redpanda.com_users.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/cluster.redpanda.com_topics.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/cluster.redpanda.com_schemas.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/cluster.redpanda.com_redpandas.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/redpanda.vectorized.io_clusters.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/redpanda.vectorized.io_consoles.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/helm-controller.yaml")) \
        + yaml.decode_all(file.read("redpanda/crd/source-controller.yaml")) \
        + yaml.decode_all(file.read("redpanda/fix_cluster_role_binding.yaml")) \
        + yaml.decode_all(file.read("manifests/knative-operator.yaml")) \
        + yaml.decode_all(file.read("manifests/tekton-pipelines.yaml"))
        [
            argocdSchema.argoHelmRelease({
                namespace = redpanda_config.redpanda.namespace
                name = "redpanda-operator"
                chart = charts.redpanda_operator
                version = "2.4.2"
                values = {
                  image.tag = "v2.2.2-24.2.4"
                }
            })

            RedPandaSchema.makeKafkaCluster(config.kafka.cluster_name)
            knative.KnativeServing {
                metadata.name = "knative-serving"
                metadata.namespace = config.knative.serving.namespace
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
                spec.version = config.knative.serving.version
                spec.config = {
                    observability = {
                        "metrics.backend-destination" = "prometheus"
                        "metrics.request-metrics-backend-destination" = "prometheus"
                        # "metrics.opencensus-address" = config.monitoring.opencensus_endpoint(config.monitoring.tempo.release_name, config.monitoring.namespace)
                    }
                    tracing = {
                        backend = "zipkin"
                        "zipkin-endpoint" = config.monitoring.zipkin_endpoint(config.monitoring.tempo.release_name, config.monitoring.namespace)
                        "sample-rate" = "1"
                        debug = "true"
                    }
                    # TODO (@metacoma) use config.zot
                    deployment = {
                        "registries-skipping-tag-resolving" = "zot-int.zot.svc.cluster.local:5000,zot-int.zot:5000,127.0.0.1:30001"
                    }
                }
            }

            knative.KnativeEventing {
                metadata.name = "knative-eventing"
                metadata.namespace = config.knative.eventing.namespace
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
                spec.version = config.knative.eventing.version
                spec.config.tracing = {
                    backend = "zipkin"
                    "zipkin-endpoint" = config.monitoring.zipkin_endpoint(config.monitoring.tempo.release_name, config.monitoring.namespace)
                    "sample-rate" = "1"
                    debug = "true"
                }
                spec.config.observability = {
                    "metrics.backend-destination" = "prometheus"
                    # "metrics.opencensus-address" = config.monitoring.opencensus_endpoint(config.monitoring.tempo.release_name, config.monitoring.namespace)
                }
            }

            k8core.ConfigMap {
                metadata.name = "config-nats"
                metadata.namespace = config.knative.eventing.namespace
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



        ]
        [
            CrossPlaneFunction.makeCrossPlaneFunction(CrossPlaneFunction.kcl)
            CrossPlaneFunction.makeCrossPlaneFunction(CrossPlaneFunction.auto_ready)
            CrossPlaneProvider.makeCrossPlaneProvider(CrossPlaneProvider.kubernetes)
            CrossPlaneProvider.makeCrossPlaneProvider(CrossPlaneProvider.http)
            argocdSchema.argoHelmRelease({
                namespace = config.istio.gateway.namespace
                name = "istio-ingressgateway"
                chart = charts.istio_gateway
                version = config.istio.version
            })
        ]
        CrossPlaneProvider.makeCrossPlaneProviderHelm(CrossPlaneProvider.helm)
        #[
        #    p.merge(resource, {
        #        metadata.annotations = {
        #            "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
        #        }
        #    })
        #    for resource in yaml.decode_all(file.read("manifests/net-istio.yaml"))
        #
        #
        #]
        [
            ProviderConfigHttp.ProviderConfig {
              metadata.name = "http-conf"
              metadata.namespace = config.config.crossplane.namespace
              spec.credentials.source = "None"
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
            }
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
        yaml.decode_all(file.read("manifests/knative/eventing-kafka-channel.yaml"))
        yaml.decode_all(file.read("manifests/knative/eventing-kafka-broker.yaml"))
        yaml.decode_all(file.read("manifests/eventing-jsm.yaml"))
        yaml.decode_all(file.read("manifests/knative/serving-default-domain.yaml"))

        [
            p.merge(resource, {
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            })
            for resource in yaml.decode_all(file.read("observability/servicemonitor.yaml"))


        ]

        [
            p.merge(resource, {
                metadata.annotations = {
                    "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
                }
            })
            for resource in XrdKclFunction.makeContextXR() + XrdKclFunction.makeUserXR() + XrdKclFunction.makeHostXR() + XrdKclFunction.makeFunctionXR()
        ]
        [
            k8core.Service {
                metadata = {
                    name = "zot-int"
                    namespace = "zot"
                }
                spec = {
                    type = "ClusterIP"
                    ports = [{
                        port = 5000
                        targetPort = "zot"
                        protocol = "TCP"
                    }]
                    selector = {
                        "app.kubernetes.io/instance" = "zot"
                        "app.kubernetes.io/name" =  "zot"
                    }
                }
            }
            k8core.Service {
                metadata = {
                    name = "dns-expose"
                    namespace = "kube-system"
                }
                spec = {
                    type = "NodePort"
                    ports = [
                      {
                        name = "dns-tcp"
                        port = 53
                        targetPort = 53
                        protocol = "TCP"
                        nodePort = 30002
                      }
                      {
                        name = "dns-udp"
                        port = 53
                        targetPort = 53
                        protocol = "UDP"
                        nodePort = 30002
                      }
                    ]
                    selector = {
                        "k8s-app" = "kube-dns"
                    }
                }
            }
            istio_gateway.Gateway {
              metadata.name = config.monitoring.gateway_name
              metadata.namespace = config.monitoring.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                selector.istio = "ingressgateway" #TODO@(metacoma) ingress release name ?
                servers = [{
                  port = {
                    number = 80
                    name = "http"
                    protocol = "HTTP"
                  }
                  hosts = [
                    config.monitoring.grafana.url,
                    config.monitoring.victoria_metrics.url,
                    config.monitoring.tempo.url,
                    config.monitoring.loki.url
                  ]
                }]
              }
            }
            istio_virtual_service.VirtualService {
              metadata.name = config.monitoring.grafana.virtual_service
              metadata.namespace = config.monitoring.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                hosts = [ config.monitoring.grafana.url ]
                gateways = [ config.monitoring.gateway_name ]
                http = [{
                  match = [{ uri.prefix = "/", port = 80}]
                  route = [{
                    destination.host = config.monitoring.grafana.destination()
                    destination.port.number = 80 # TODO(@metacoma) hardcode
                  }]

                }]
              }
            }


            istio_virtual_service.VirtualService {
              metadata.name = config.monitoring.loki.virtual_service
              metadata.namespace = config.monitoring.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                hosts = [ config.monitoring.loki.url ]
                gateways = [ config.monitoring.gateway_name ]
                http = [{
                  match = [{ uri.prefix = "/", port = 80}]
                  route = [{
                    destination.host = config.monitoring.loki.destination()
                    destination.port.number = 80 # TODO(@metacoma) hardcode
                  }]

                }]
              }
            }

            istio_virtual_service.VirtualService {
              metadata.name = config.monitoring.tempo.virtual_service
              metadata.namespace = config.monitoring.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                hosts = [ config.monitoring.tempo.url ]
                gateways = [ config.monitoring.gateway_name ]
                http = [{
                  match = [{ uri.prefix = "/", port = 80}]
                  route = [{
                    destination.host = config.monitoring.tempo.destination()
                    destination.port.number = 3100
                  }]

                }]
              }
            }

            istio_virtual_service.VirtualService {
              metadata.name = config.monitoring.victoria_metrics.virtual_service
              metadata.namespace = config.monitoring.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                hosts = [ config.monitoring.victoria_metrics.url ]
                gateways = [ config.monitoring.gateway_name ]
                http = [{
                  match = [{ uri.prefix = "/", port = 80}]
                  route = [{
                    destination.host = config.monitoring.victoria_metrics.destination()
                    destination.port.number = 8429 # TODO(@metacoma) hardcode
                  }]

                }]
              }
            }


            istio_gateway.Gateway {
              metadata.name = config.argocd.gateway_name
              metadata.namespace = config.argocd.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                selector.istio = "ingressgateway" #TODO@(metacoma) ingress release name ?
                servers = [{
                  port = {
                    number = 80
                    name = "http"
                    protocol = "HTTP"
                  }
                  hosts = [
                    config.argocd.url
                  ]
                }]
              }
            }

            istio_virtual_service.VirtualService {
              metadata.name = config.argocd.virtual_service
              metadata.namespace = config.argocd.namespace
              metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
              }
              spec = {
                hosts = [ config.argocd.url ]
                gateways = [ config.argocd.gateway_name ]
                http = [{
                  match = [{ uri.prefix = "/", port = 80}]
                  route = [{
                    destination.host = config.argocd.destination()
                    destination.port.number = 38080 # TODO(@metacoma) hardcode
                  }]

                }]
              }
            }
          ]
    ]
})

manifests.yaml_stream([
    mindwm_app
])
