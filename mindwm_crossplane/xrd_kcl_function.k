import manifests
import yaml
import k8s.api.core.v1 as k8core
import template
import ..config as config
import ..helm.chart as charts
import file

api_version = "apiextensions.crossplane.io/v1"

composite_version = "v1beta1"

kcl_util_func = file.read("./config.k")
kcl_config_schema = file.read("./config_schema.k")


# TODO(@metacoma) rewrite using knative-operator module
mkComposition = lambda claim_ref : any, schemaSpec : any, steps :[any] {
    group = claim_ref.apiVersion.split("/")[0]
    [
        {
            apiVersion = api_version
            kind = "CompositeResourceDefinition"
            metadata.name = "x" + claim_ref.kind + "s." + group
            spec = {
                group = group
                names = {
                    kind = "X" + claim_ref.kind.capitalize()
                    plural = "x" + claim_ref.kind + "s"
                }
                claimNames = {
                    kind = claim_ref.kind.capitalize()
                    plural = claim_ref.kind + "s"
                }
                # TODO(@metacoma) currently support only one version
                versions = [
                    {
                        name = composite_version
                        referenceable = True
                        served = True
                        schema.openAPIV3Schema = {
                            type = "object"
                            properties.spec = schemaSpec
                        }

                    }
                ]

            }
        }
        {
            apiVersion = api_version
            kind = "Composition"
            metadata.name = claim_ref.kind
            spec = {
                compositeTypeRef = {
                    apiVersion = claim_ref.apiVersion
                    kind = "X" + claim_ref.kind.capitalize()
                }
                mode = "Pipeline"
                pipeline = steps + [
                    {
                        step = "automatically-detect-ready-composed-resources"
                        functionRef.name = "function-auto-ready" # required installed function function-auto-ready
                    }
                ]
            }
        }
    ]
}

makeContextXR = lambda {
    mkComposition({
        apiVersion = "mindwm.io/" + composite_version
        kind = "context"
    }, {
        type = "object"
        properties.name.type = "string"
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLInput"
                spec.dependencies = """\
                k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.32.4" }
                crossplane = { oci = "oci://ghcr.io/kcl-lang/crossplane", tag = "1.17.3" }
                crossplane-provider-kubernetes = { oci = "oci://ghcr.io/kcl-lang/crossplane-provider-kubernetes", tag = "0.9.2" }
                crossplane_provider_http = { oci = "oci://ghcr.io/kcl-lang/crossplane-provider-http", tag = "1.0.8" }
                knative-operator = { oci = "oci://ghcr.io/kcl-lang/knative-operator", tag = "0.3.0" }
                knative = { oci = "oci://ghcr.io/kcl-lang/knative", tag = "0.2.0" }
                istio = { oci = "oci://ghcr.io/kcl-lang/istio", tag = "1.21.5" }
                json_merge_patch = { oci = "oci://ghcr.io/kcl-lang/json_merge_patch", tag = "0.1.1" }
                """
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.source = template.execute("""\
import k8s.api.core.v1 as k8core
import crossplane.v1alpha1.helm_crossplane_io_v1alpha1_release as crossplane_helm
import crossplane_provider_kubernetes.v1alpha1.kubernetes_crossplane_io_v1alpha1_object as crossplane_kubernetes
import knative.v1.eventing_knative_dev_v1_broker as knative_broker
import knative.v1.serving_knative_dev_v1_service as knative_service
import istio.v1alpha3.networking_istio_io_v1alpha3_gateway as istio_gateway
import istio.v1alpha3.networking_istio_io_v1alpha3_virtual_service as istio_virtual_service
import crossplane_provider_http.v1alpha2.http_crossplane_io_v1alpha2_disposable_request as DisposableRequest
import json
${kcl_util_func}
${kcl_config_schema}
context_name = option("params").oxr.spec.name
ctx = MindwmContext {
    name.data = "{{ context_name }}"
}
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = crossplaneResourceName(ctx, ctx.namespace)
    spec.forProvider.manifest = k8core.Namespace {
      metadata.name = getData(ctx.namespace)
      metadata.labels = {
          "istio-injection" = "enabled"
      }
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = crossplaneResourceName(ctx, ctx.neo4j.plugin_pvc_name)
    spec.forProvider.manifest = k8core.PersistentVolumeClaim {
        metadata.name = getData(ctx.neo4j.plugin_pvc_name)
        metadata.namespace = getData(ctx.namespace)
        spec = {
          accessModes = [ "ReadWriteOnce" ]
          resources.requests.storage = "1Gi"
        }
    }
  }
  # redpanda (kafka topic) for broadcast graph changes to process eventing
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = crossplaneResourceName(ctx, ctx.cdc_topic.name)
    spec.forProvider.manifest = {
        apiVersion = "cluster.redpanda.com/v1alpha1"
        kind = "Topic"
        metadata = {
            name = getData(ctx.cdc_topic.name)
            namespace = getData(ctx.kafka.namespace)
        }
        spec = {
            partitions = 1
            replicationFactor = 1
            additionalConfig = {
                "cleanup.policy" = "compact"
            }
            kafkaApiSpec.brokers = ctx.kafka.bootstrap_servers
        }
    }
  }
  crossplane_helm.Release {
    metadata.name = crossplaneResourceName(ctx, ctx.neo4j.name)
    spec.forProvider = {
        namespace = getData(ctx.namespace)
        chart = {
          name = "${charts.neo4j.name}"
          repository = "${charts.neo4j.repoURL}"
          version = "${config.neo4j.version}"
        }
        values = {
            additionalVolumeMounts = [
                {
                    mountPath = "/var/lib/neo4j/plugins"
                    name = getData(ctx.neo4j.plugin_pvc_name)
                }
            ]
            additionalVolumes = [
                {
                    name = getData(ctx.neo4j.plugin_pvc_name)
                    persistentVolumeClaim.claimName = getData(ctx.neo4j.plugin_pvc_name)
                }
            ]
            env = {
                "NEO4J_apoc_export_file_enabled" = "true"
                "NEO4J_apoc_import_file_enabled" = "true"
                "NEO4J_apoc_import_file_use__neo4j__config" = "true"
                "NEO4J_dbms_logs_debug_level" = "DEBUG"
                "NEO4J_kafka_bootstrap_servers" = "${config.kafka.brokerEndpoint}"
                "NEO4J_streams_source_topic_nodes_" + getData(ctx.cdc_topic.name) = "*"
                "NEO4J_streams_source_topic_relationships_"+ getData(ctx.cdc_topic.name) = '*'
            }
            neo4j.password = "${config.neo4j.password}"
            services.neo4j.spec.type = "NodePort"
            neo4j.labels = {
                "sidecar.istio.io/inject" = "false"
            }
            neo4j.resources = {
                cpu = "500m"
                memory: "2Gi"
            }
            volumes = {
                data = {
                    dynamic = {
                        storageClassName = "local-path"
                        requests.storage = "5Gi"
                    }
                    mode = "dynamic"
                }
            }
            # TODO(@metacoma) k8.core.podSpec
            podSpec.initContainers = [
                {
                    image = "curlimages/curl:8.6.0"
                    name = "install-apoc-plugin"
                    user = "root"
                    volumeMounts = [{
                        mountPath = "/var/lib/neo4j/plugins"
                        name = getData(ctx.neo4j.plugin_pvc_name)
                    }]
                    workingDir = "/var/lib/neo4j/plugins"
                    command = [
                        "curl",
                        "--retry"
                        "3"
                        "-Lo"
                        "apoc.jar"
                        "--no-clobber"
                        "https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/4.4.0.36/apoc-4.4.0.36-all.jar"
                    ]
                }
                {
                    image = "curlimages/curl:8.6.0"
                    name = "install-neo4j-stream-plugin"
                    user = "root"
                    workingDir = "/var/lib/neo4j/plugins"
                    volumeMounts = [{
                        mountPath = "/var/lib/neo4j/plugins"
                        name = getData(ctx.neo4j.plugin_pvc_name)
                    }]
                    command = [
                        "curl",
                        "--retry"
                        "3"
                        "-Lo"
                        "streams.jar"
                        "--no-clobber"
                        "https://github.com/neo4j-contrib/neo4j-streams/releases/download/4.1.6/neo4j-streams-4.1.6.jar"
                    ]
                }
            ]

        }
    }
  }
  crossplane_helm.Release {
    metadata.name = ctx.name.data + "-node-red"
    spec.forProvider = {
        namespace = getData(ctx.namespace)
        chart = {
          name = "${charts.node_red.name}"
          repository = "${charts.node_red.repoURL}"
          version = "${config.node_red.helm_chart_version}"
        }
        values = {
          resources = {
            limits = {
              cpu = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu = "75m"
              memory = "64Mi"
            }
          }
          podLabels = {
            "sidecar.istio.io/inject" = "false"
          }
       }
    }
  }
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.broker.configMapName)
    spec.forProvider.manifest = k8core.ConfigMap {
        metadata = {
            name = getData(ctx.broker.configMapName)
            namespace = getData(ctx.namespace)
        }
        data = {
            "channel-template-spec" = '''\
apiVersion: messaging.knative.dev/v1
kind: InMemoryChannel
'''
        }
    }

  }
  # contextBroker
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.broker.name)
    spec.forProvider.manifest = knative_broker.Broker {
      metadata = {
        name = getData(ctx.broker.name)
        namespace = getData(ctx.namespace)
        annotations = {
          "eventing.knative.dev/broker.class" = "MTChannelBasedBroker"
        }

      }
      spec.config = {
          apiVersion = "v1"
          kind = "ConfigMap"
          name = getData(ctx.broker.configMapName)
      }
    }
  }
  # kafkaSource
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.kafkaSource.name)
    spec.forProvider.manifest = {
      apiVersion = "sources.knative.dev/v1beta1"
      kind = "KafkaSource"
      metadata = {
        name = getData(ctx.kafkaSource.name)
        namespace = getData(ctx.namespace)
      }
      spec = {
            bootstrapServers = ctx.kafka.bootstrap_servers
            consumerGroup = "knative-group"
            sink.ref = {
                apiVersion = "eventing.knative.dev/v1"
                kind = "Broker"
                name = getData(ctx.broker.name)
            }
            topics = [ getData(ctx.cdc_topic.name) ]
      }
    }
  }
  # deadLetter service
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.broker.deadLetter.name)
    spec.forProvider.manifest = knative_service.Service {
      metadata = {
        name = getData(ctx.broker.deadLetter.name)
        namespace = getData(ctx.namespace)
      }
      spec.template.spec.containers = [{
          image = ctx.broker.deadLetter.image
          env = [{
            name = "REQUEST_LOGGING_ENABLED"
            value = "1"
          }]
      }]
    }
  }
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.broker.virtual_service.name)
    spec.forProvider.manifest = istio_virtual_service.VirtualService {
      metadata.name = getData(ctx.broker.virtual_service.name)
      metadata.namespace = getData(ctx.namespace)
      spec = {
        # TODO @(metacoma) hardcode
        hosts = [
          "broker-ingress.knative-eventing.svc.cluster.local"
        ]
        # TODO @(metacoma) hardcode
        gateways = [
          "knative-serving/knative-ingress-gateway",
          "knative-serving/knative-local-gateway"
        ]
        http = [{
          match = [{ uri.regex = ".*"}]
          route = [{
            # TODO (@metacoma) hardcode
            destination.host = "broker-ingress.knative-eventing.svc.cluster.local"
            destination.port.number = 80 # TODO(@metacoma) hardcode
          }]
        }]
      }
    }
  }
  # io_context
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.io_context.name)
    spec.forProvider.manifest = knative_service.Service {
      metadata = {
        name = getData(ctx.io_context.name)
        namespace = getData(ctx.namespace)
      }
      spec.template.spec.containers = [{
          image = ctx.io_context.image
          env = [
            {
              name = "NEO4J_URI"
              value = "bolt://" + getData(ctx.name) + "-" + getData(ctx.neo4j.name) + "-neo4j:" + str(ctx.neo4j.port)
            }
            {
              name = "NEO4J_USERNAME"
              value =  ctx.neo4j.username
            }
            {
              name = "NEO4J_PASSWORD"
              value = ctx.neo4j.password
            }
            {
              name = "CONTEXT_NAME"
              value = getData(ctx.name)
            }
            {
              name = "OTEL_EXPORTER_OTLP_ENDPOINT"
              value = "http://${config.monitoring.otel_collector.release_name}-opentelemetry-collector.${config.monitoring.namespace}:4317"
            }
            {
              name = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
              value = "http://${config.monitoring.tempo.release_name}.${config.monitoring.namespace}:4317/v1/traces"
            }
          ]
      }]
    }
  }

  # io-trigger
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.io_context.name) + "-trigger"
    spec.forProvider.manifest = {
      apiVersion = "eventing.knative.dev/v1"
      kind = "Trigger"
      metadata = {
        name = getData(ctx.io_context.name) + "-trigger"
        namespace = getData(ctx.namespace)
      }
      spec = {
        broker = getData(ctx.broker.name)
        delivery.deadLetterSink.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.broker.deadLetter.name)
        }
        filters = [{
          "all" = [
            {
              exact.type = "org.mindwm.v1.iodocument"
            }
            {
              "not" = { prefix.subject = "#" }
            }
          ]
        }]
        subscriber.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.io_context.name)
        }
      }
    }
  }

  # pong
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.pong.name)
    spec.forProvider.manifest = knative_service.Service {
      metadata = {
        name = getData(ctx.pong.name)
        namespace = getData(ctx.namespace)
      }
      spec.template.spec.containers = [{
          image = ctx.pong.image
          env = [
            {
              name = "OTEL_EXPORTER_OTLP_ENDPOINT"
              value = "http://${config.monitoring.otel_collector.release_name}-opentelemetry-collector.${config.monitoring.namespace}:4317"
            }
            {
              name = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
              value = "http://${config.monitoring.tempo.release_name}.${config.monitoring.namespace}:4317/v1/traces"
            }
          ]
      }]
    }
  }
  #pong trigger
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.pong.name) + "-trigger"
    spec.forProvider.manifest = {
      apiVersion = "eventing.knative.dev/v1"
      kind = "Trigger"
      metadata = {
        name = getData(ctx.pong.name) + "-trigger"
        namespace = getData(ctx.namespace)
      }
      spec = {
        broker = getData(ctx.broker.name)
        delivery.deadLetterSink.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.broker.deadLetter.name)
        }
        filters = [{
          "all" = [
            {
              exact.type = "org.mindwm.v1.iodocument"
            }
            {
              prefix.subject = "#"
            }
          ]
        }]
        subscriber.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.pong.name)
        }
      }
    }
  }

  # kafka_cdc
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.kafka_cdc.name)
    spec.forProvider.manifest = knative_service.Service {
      metadata = {
        name = getData(ctx.kafka_cdc.name)
        namespace = getData(ctx.namespace)
      }
      spec.template.spec.containers = [{
          image = ctx.kafka_cdc.image
          env = [
            {
              name = "NEO4J_URI"
              value = "bolt://" + getData(ctx.name) + "-" + getData(ctx.neo4j.name) + "-neo4j:" + str(ctx.neo4j.port)
            }
            {
              name = "NEO4J_USERNAME"
              value =  ctx.neo4j.username
            }
            {
              name = "NEO4J_PASSWORD"
              value = ctx.neo4j.password
            }
            {
              name = "CONTEXT_NAME"
              value = getData(ctx.name)
            }
            {
              name = "OTEL_EXPORTER_OTLP_ENDPOINT"
              value = "http://${config.monitoring.otel_collector.release_name}-opentelemetry-collector.${config.monitoring.namespace}:4317"
            }
            {
              name = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
              value = "http://${config.monitoring.tempo.release_name}.${config.monitoring.namespace}:4317/v1/traces"
            }
          ]
      }]
    }
  }

  #kafka-cdc trigger
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.kafka_cdc.name) + "-trigger"
    spec.forProvider.manifest = {
      apiVersion = "eventing.knative.dev/v1"
      kind = "Trigger"
      metadata = {
        name = getData(ctx.kafka_cdc.name) + "-trigger"
        namespace = getData(ctx.namespace)
      }
      spec = {
        broker = getData(ctx.broker.name)
        delivery.deadLetterSink.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.broker.deadLetter.name)
        }
        filters = [{
          "all" = [
            {
              exact.type = "dev.knative.kafka.event"
            }
            {
              "not" = { prefix.source = "org.mindwm" }
            }
          ]
        }]
        subscriber.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.kafka_cdc.name)
        }
      }
    }
  }

  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.clipboard.name)
    spec.forProvider.manifest = knative_service.Service {
      metadata = {
        name = getData(ctx.clipboard.name)
        namespace = getData(ctx.namespace)
      }
      spec.template.spec.containers = [{
          image = ctx.clipboard.image
          env = [
            {
              name = "NEO4J_URI"
              value = "bolt://" + getData(ctx.name) + "-" + getData(ctx.neo4j.name) + "-neo4j:" + str(ctx.neo4j.port)
            }
            {
              name = "NEO4J_USERNAME"
              value =  ctx.neo4j.username
            }
            {
              name = "NEO4J_PASSWORD"
              value = ctx.neo4j.password
            }
            {
              name = "CONTEXT_NAME"
              value = getData(ctx.name)
            }
            {
              name = "OTEL_EXPORTER_OTLP_ENDPOINT"
              value = "http://${config.monitoring.otel_collector.release_name}-opentelemetry-collector.${config.monitoring.namespace}:4317"
            }
            {
              name = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
              value = "http://${config.monitoring.tempo.release_name}.${config.monitoring.namespace}:4317/v1/traces"
            }
          ]
      }]
    }
  }
  #clipboard trigger
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.clipboard.name) + "-trigger"
    spec.forProvider.manifest = {
      apiVersion = "eventing.knative.dev/v1"
      kind = "Trigger"
      metadata = {
        name = getData(ctx.clipboard.name) + "-trigger"
        namespace = getData(ctx.namespace)
      }
      spec = {
        broker = getData(ctx.broker.name)
        delivery.deadLetterSink.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.broker.deadLetter.name)
        }
        filters = [{
          "all" = [
            {
              exact.type = "org.mindwm.v1.clipboard"
            }
          ]
        }]
        subscriber.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(ctx.clipboard.name)
        }
      }
    }
  }

  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.gateway.name)
    spec.forProvider.manifest = istio_gateway.Gateway {
      metadata.name = getData(ctx.gateway.name)
      metadata.namespace = getData(ctx.namespace)
      spec = {
        selector.istio = "ingressgateway" #TODO@(metacoma) ingress release name ?
        servers = [{
          port = {
            number = 80
            name = "http"
            protocol = "HTTP"
          }
          hosts = [
            "*." + getData(ctx.name) + ".mindwm.local"
          ]
        }]
      }
    }
  }

  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.neo4j_virtual_service.name)
    spec.forProvider.manifest = istio_virtual_service.VirtualService {
      metadata.name = getData(ctx.neo4j_virtual_service.name)
      metadata.namespace = getData(ctx.namespace)
      spec = {
        hosts = [
          "neo4j." + getData(ctx.name) + ".mindwm.local"
        ]
        gateways = [ getData(ctx.gateway.name) ]
        http = [{
          match = [{ uri.prefix = "/", port = 80}]
          route = [{
            destination.host = getData(ctx.name) + "-" + getData(ctx.neo4j.name)
            destination.port.number = ctx.neo4j.port # TODO(@metacoma) hardcode
          }]

        }]
      }
    }
  }
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(ctx, ctx.node_red_virtual_service.name)
    spec.forProvider.manifest = istio_virtual_service.VirtualService {
      metadata.name = "node-red"
      metadata.namespace = getData(ctx.namespace)
      spec = {
        hosts = [
          "node-red." + getData(ctx.name) + ".mindwm.local"
        ]
        gateways = [ getData(ctx.gateway.name) ]
        http = [{
          match = [{ uri.prefix = "/", port = 80}]
          route = [{
            destination.host = getData(ctx.name) + "-node-red"
            destination.port.number = 1880 # TODO(@metacoma) hardcode
          }]

        }]
      }
    }
  }

  # node-red context tab
  crossplane_kubernetes.Object {
    metadata.name = getData(ctx.name) + "-node-red-context-tab"
    spec.forProvider.manifest = DisposableRequest.DisposableRequest {
      metadata.name = "context-" + getData(ctx.name) + "-tab"
      metadata.namespace = getData(ctx.namespace)
      spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            url = "http://" + getData(ctx.name) + "-node-red." + getData(ctx.namespace) + ".svc.cluster.local:1880/flow"
            method = "POST"
            headers = {
              "Content-type" = [ "application/json" ]
            }
            rollbackRetriesLimit = 128
            shouldLoopInfinitely = True
            nextReconcile = "30s"
            body = json.encode({
              "id" = getData(ctx.namespace)
              "type" = "tab"
              "label" = getData(ctx.namespace)
              "nodes" = []
              "configs" = []
            })
        }
        providerConfigRef = {
          name = "http-conf"
        }
      }
    }
  }

]
""", {
    context_name = r"${context_name}"
})
            }
        }
    ])
}

makeUserXR = lambda {
    mkComposition({
        apiVersion = "mindwm.io/" + composite_version
        kind = "user"
    }, {
        type = "object"
        properties.name.type = "string"
        properties.context = {
            type = "array"
            items.type = "string"
        }
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLInput"
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.dependencies = """\
                k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.32.4" }
                knative = { oci = "oci://ghcr.io/kcl-lang/knative", tag = "0.2.0" }
                crossplane-provider-kubernetes = { oci = "oci://ghcr.io/kcl-lang/crossplane-provider-kubernetes", tag = "0.9.0" }
                istio = { oci = "oci://ghcr.io/kcl-lang/istio", tag = "1.21.5" }
                crossplane_provider_http = { oci = "oci://ghcr.io/kcl-lang/crossplane-provider-http", tag = "1.0.8" }
                """
                spec.source = template.execute("""\
import k8s.api.core.v1 as k8core
import knative.v1.serving_knative_dev_v1_service as knative_service
import knative.v1.eventing_knative_dev_v1_broker as knative_broker
import crossplane_provider_kubernetes.v1alpha1.kubernetes_crossplane_io_v1alpha1_object as crossplane_kubernetes
import istio.v1alpha3.networking_istio_io_v1alpha3_gateway as istio_gateway
import istio.v1alpha3.networking_istio_io_v1alpha3_virtual_service as istio_virtual_service
import crossplane_provider_http.v1alpha2.http_crossplane_io_v1alpha2_disposable_request as DisposableRequest
import json
${kcl_util_func}
${kcl_config_schema}
user_name = option("params").oxr.spec.name
context_names = option("params").oxr.spec.context
contexts = [
  MindwmContext { name.data = context_name }
  for context_name in context_names
]
user = MindwmUser { name.data = user_name }
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = crossplaneResourceName(user, user.namespace)
    spec.forProvider.manifest = k8core.Namespace {
      metadata.name = getData(user.namespace)
      metadata.labels = {
          "istio-injection" = "enabled"
      }
    }
  }
  # deadLetter service
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(user, user.broker.deadLetter.name)
    spec.forProvider.manifest = knative_service.Service {
      metadata = {
        name = getData(user.broker.deadLetter.name)
        namespace = getData(user.namespace)
      }
      spec.template.spec.containers = [{
          image = user.broker.deadLetter.image
          env = [{
            name = "REQUEST_LOGGING_ENABLED"
            value = "1"
          }]
      }]
    }
  }
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(user, user.broker.configMapName)
    spec.forProvider.manifest = k8core.ConfigMap {
        metadata = {
            name = getData(user.broker.configMapName)
            namespace = getData(user.namespace)
        }
        data = {
            "channel-template-spec" = '''\
  apiVersion: messaging.knative.dev/v1
  kind: InMemoryChannel
  '''
        }
    }
  }

  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(user, user.broker.name)
    spec.forProvider.manifest = knative_broker.Broker {
      metadata = {
        name = getData(user.broker.name)
        namespace = getData(user.namespace)
        annotations = {
          "eventing.knative.dev/broker.class" = "MTChannelBasedBroker"
        }
      }
      spec.config = {
          apiVersion = "v1"
          kind = "ConfigMap"
          name = getData(user.broker.configMapName)
      }
    }
  }

] + [
    # user broker -> context broker
    crossplane_kubernetes.Object {
      metadata.name = crossplane_user2context_trigger_name(user, ctx)
      spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Trigger"
        metadata = {
          name = crossplane_user2context_trigger_name(user, ctx)
          namespace = getData(user.namespace)
        }
        spec = {
          broker = getData(user.broker.name)
          delivery.deadLetterSink.ref = {
            apiVersion = "serving.knative.dev/v1"
            kind = "Service"
            name = getData(user.broker.deadLetter.name)
          }
          filters = [{
            "any" = [
              {exact.type = "org.mindwm.v1.iodocument"}
              {exact.type = "org.mindwm.v1.clipboard"}
              {exact.type = "org.mindwm.v1.ping"}
            ]
          }]
          subscriber.ref = {
            apiVersion = "eventing.knative.dev/v1"
            kind = "Broker"
            namespace = getData(ctx.namespace)
            name = getData(ctx.broker.name)
          }
        }
      }
    }
    for ctx in contexts
] + [
    # node-red in context node-red
    crossplane_kubernetes.Object {
      metadata.name = getData(ctx.name) + "-user-" + getData(user.name) + "-node-red-user-tab"
      spec.forProvider.manifest = DisposableRequest.DisposableRequest {
        metadata.name = "context-" + getData(ctx.name) +  "-user-" + getData(user.name) + "-tab"
        metadata.namespace = getData(user.namespace)
        spec = {
          deletionPolicy = "Orphan"
          forProvider = {
              url = "http://" + getData(ctx.name) + "-node-red." + getData(ctx.namespace) + ".svc.cluster.local:1880/flow"
              method = "POST"
              headers = {
                "Content-type" = [ "application/json" ]
              }
              rollbackRetriesLimit = 128
              shouldLoopInfinitely = True
              nextReconcile = "30s"
              body = json.encode({
                "id" = getData(user.namespace)
                "type" = "tab"
                "label" = getData(user.namespace)
                "nodes" = []
                "configs" = []
              })
          }
          providerConfigRef = {
            name = "http-conf"
          }
        }
      }
    }
    for ctx in contexts
] + [
    # context broker -> user broker
    crossplane_kubernetes.Object {
      metadata.name = crossplane_context2user_trigger_name(user, ctx)
      spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Trigger"
        metadata = {
          name = crossplane_context2user_trigger_name(user, ctx)
          namespace = getData(ctx.namespace)
        }
        spec = {
          broker = getData(ctx.broker.name)
          delivery.deadLetterSink.ref = {
            apiVersion = "serving.knative.dev/v1"
            kind = "Service"
            name = getData(ctx.broker.deadLetter.name)
          }
          filters = [{
            "all" = [
                { cesql = "source NOT LIKE 'org.mindwm." + getData(user.name) + "._%'" }
                { cesql = "subject LIKE 'org.mindwm." + getData(user.name) + "._%' OR source LIKE 'org.mindwm.context." + getData(ctx.name) + "._%'" }
                #{ cesql = "source LIKE 'org.mindwm.context." + getData(ctx.name) + ".graph.%'" }
            ]
          }]
          subscriber.ref = {
            apiVersion = "eventing.knative.dev/v1"
            kind = "Broker"
            namespace = getData(user.namespace)
            name = getData(user.broker.name)
          }
        }
      }
    }
    for ctx in contexts
]
""", {
    user_name = r"${user_name}"
    context_names = r"${context_names}"
    context_name = r"${context_name}"
})
            }
        }
    ])
}



makeHostXR = lambda {
    mkComposition({
        apiVersion = "mindwm.io/" + composite_version
        kind = "host"
    }, {
        type = "object"
        properties.name.type = "string"
        properties.username.type = "string"
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLInput"
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.dependencies = """\
                k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.32.4" }
                knative = { oci = "oci://ghcr.io/kcl-lang/knative", tag = "0.2.0" }
                crossplane-provider-kubernetes = { oci = "oci://ghcr.io/kcl-lang/crossplane-provider-kubernetes", tag = "0.9.0" }
                """
                spec.source = template.execute("""\
import k8s.api.core.v1 as k8core
import knative.v1.serving_knative_dev_v1_service as knative_service
import knative.v1.eventing_knative_dev_v1_broker as knative_broker
import crossplane_provider_kubernetes.v1alpha1.kubernetes_crossplane_io_v1alpha1_object as crossplane_kubernetes
${kcl_util_func}
${kcl_config_schema}
host_name = option("params").oxr.spec.name
user_name = option("params").oxr.spec.username

host = MindwmHost { name.data = host_name }
user = MindwmUser { name.data = user_name }
items = [
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(host, host.broker.configMapName)
    spec.forProvider.manifest = k8core.ConfigMap {
        metadata = {
            name = getData(host.broker.configMapName)
            namespace = getData(user.namespace)
        }
        data = {
            "channel-template-spec" = '''\
  apiVersion: messaging.knative.dev/v1alpha1
  kind: NatsJetStreamChannel
  spec:
    stream:
      config:
        additionalSubjects:
          - "org.mindwm.{{ user_name }}.{{ host_name }}.>"
        overrideName: {{ host_name }}
  '''
        }
    }
  }
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(host, host.broker.name)
    spec.forProvider.manifest = knative_broker.Broker {
      metadata = {
        name = getData(host.broker.name)
        namespace = getData(user.namespace)
        annotations = {
          "eventing.knative.dev/broker.class" = "MTChannelBasedBroker"
        }

      }
      spec.config = {
          apiVersion = "v1"
          kind = "ConfigMap"
          name = getData(host.broker.configMapName)
      }
    }
  }
  # hostBroker -> UserBroker trigger
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(host, host.trigger.name)
    spec.forProvider.manifest = {
      apiVersion = "eventing.knative.dev/v1"
      kind = "Trigger"
      metadata = {
        # TODO(@metacoma) -trigger
        name = getData(host.trigger.name) + "-trigger"
        namespace = getData(user.namespace)
      }
      spec = {
        broker = getData(host.broker.name)
        delivery.deadLetterSink.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(user.broker.deadLetter.name)
        }
        filters = [{
          # TODO (@metacoma) use variables
          "any" = [
            {exact.type = "org.mindwm.v1.iodocument"}
            {exact.type = "org.mindwm.v1.clipboard"}
            {exact.type = "org.mindwm.v1.ping"}
          ]
        }]
        subscriber.ref = {
          apiVersion = "eventing.knative.dev/v1"
          kind = "Broker"
          name = getData(user.broker.name)
          namespace = getData(user.namespace)
        }
      }

    }
  }
  crossplane_kubernetes.Object {
    metadata.name = crossplaneResourceName(host, host.trigger_back.name)
    spec.forProvider.manifest = {
      apiVersion = "eventing.knative.dev/v1"
      kind = "Trigger"
      metadata = {
        name = getData(host.trigger_back.name)
        namespace = getData(user.namespace)
      }
      spec = {
        broker = getData(user.broker.name)
        delivery.deadLetterSink.ref = {
          apiVersion = "serving.knative.dev/v1"
          kind = "Service"
          name = getData(user.broker.deadLetter.name)
        }
        filters = [{
          "all" = [
            { cesql = "source NOT LIKE 'org.mindwm." + getData(user.name) + "._%'" }
            { cesql = "subject LIKE 'org.mindwm." + getData(user.name) + "._%' OR source LIKE 'org.mindwm.context._%'" }
            #{ cesql = "source LIKE 'org.mindwm.context." + getData(ctx.name) + ".graph.%'" }
          ]
        }]
        subscriber.ref = {
          apiVersion = "eventing.knative.dev/v1"
          kind = "Broker"
          name = getData(host.broker.name)
          namespace = getData(user.namespace)
        }
      }

    }
  }
]
""", {
    user_name = r"${user_name}"
    host_name = r"${host_name}"
})
            }
        }
    ])
}

makeFunctionXR = lambda {
    mkComposition({
        apiVersion = "mindwm.io/" + composite_version
        kind = "function"
    }, {
        type = "object"
        properties.data.type = "object"
        properties.data.additionalProperties.type = "string"
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLInput"
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.dependencies = """\
                k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.32.4" }
                tekton_pipelines = { oci = "oci://ghcr.io/kcl-lang/tekton-pipelines", tag = "1.0.0" }
                knative = { oci = "oci://ghcr.io/kcl-lang/knative", tag = "0.2.0" }
                crossplane-provider-kubernetes = { oci = "oci://ghcr.io/kcl-lang/crossplane-provider-kubernetes", tag = "0.9.0" }
                """
                spec.source = template.execute("""\
import yaml
import k8s.api.core.v1 as k8core
import knative.v1.serving_knative_dev_v1_service as knative_service
import knative.v1.eventing_knative_dev_v1_broker as knative_broker
import crossplane_provider_kubernetes.v1alpha1.kubernetes_crossplane_io_v1alpha1_object as crossplane_kubernetes
import tekton_pipelines.v1beta1.tekton_dev_v1beta1_pipeline_run as PipelineRun
import regex
${kcl_util_func}
${kcl_config_schema}

function_xrd = option("params").oxr.spec.data

python_indent = '''
    '''

function = yaml.encode({
  ".funcignore" = "filestoignore"
  ".gitignore" = "/.func"
  "Procfile" = "web: python -m parliament ."
  "README.md" = "README"
  "app.sh" = '''\
#!/bin/sh
exec python -m parliament "$(dirname "$0")"
'''
  "func.py" = '''\
from cloudevents.http import CloudEvent
from parliament import Context
from flask import Request
import json

def main(context: Context):
    print("Received CloudEvent: ", context.cloud_event)
    print(f"Method: {context.request.method}")
    print(f"Event data {context.cloud_event.data}")
    attributes = context.cloud_event.get_attributes()
    data = context.cloud_event.data

''' + regex.replace(function_xrd["func.py"], "(^|\\n)", python_indent)

  "func.yaml" = '''\
specVersion: 0.36.0
name: mindwm-function
runtime: python
created: 2024-12-17T21:55:03.525539663+01:00
'''
  "requirements.txt" = '''\
parliament-functions==0.1.0
''' + function_xrd["requirements.txt"]
  "test_func.py" = '''\
import unittest
func = __import__("func")
class TestFunc(unittest.TestCase):
  def test_func_empty_request(self):
    resp, code = func.main({})
    self.assertEqual(resp, "{}")
    self.assertEqual(code, 200)
if __name__ == "__main__":
  unittest.main()
'''
})

#function = yaml.encode(option("params").oxr.spec.data)

#function = yaml.encode(option("params"))
function_name = option("params").oxr.spec.claimRef.name
function_namespace = option("params").oxr.spec.claimRef.namespace
configmap_name = "mindwm-function-" + function_name + "-configmap"

items = [
  crossplane_kubernetes.Object {
    metadata.name = "mindwm-function-{{ function_name }}-configmap"
    spec.forProvider.manifest = k8core.ConfigMap {
        metadata = {
            name = "{{ configmap_name }}"
            namespace = "{{ function_namespace }}"
        }
        data = yaml.decode("{{ function }}")
    }
  }

  crossplane_kubernetes.Object {
    metadata.name = "mindwm-function-{{ function_name }}-pipeline"
    spec.forProvider.manifest = PipelineRun.PipelineRun {
        metadata.name = "mindwm-function-{{ function_name }}-build-and-push"
        metadata.namespace = "{{ function_namespace }}"
        metadata.annotations = {
          "sidecar.istio.io/inject" = "false"
        }
        spec.pipelineSpec = {
            workspaces: [
                { name = "build" }
                { name = "source" }
            ]
            tasks = [
                {
                    name = "copy-function-files"
                    taskSpec.steps = [{
                        name = "copy-function-files"
                        image = "busybox"
                        script = '''#!/bin/sh
                        find /workspace
                        cp -vLr /workspace/source/* /workspace/build
                        '''
                    }]
                    workspaces = [
                        {name = "source", workspace = "source" }
                        {name = "build", workspace = "build" }
                    ]
                }
                {
                    name = "buildpack"
                    params = [
                        { name = "REGISTRY_ENDPOINT", value = "zot-int.zot.svc.cluster.local:5000" }
                        { name = "REPO", value = "{{ function_namespace }}" }
                        { name = "IMAGE", value = "{{ function_name }}" }
                    ]
                    taskSpec.steps = [
                        {
                            name = "pack-build"
                            env = [
                             { name = "CNB_INSECURE_REGISTRIES" value = "zot-int.zot:5000;zot.zot.svc.cluster.local:5000" }
                            ]
                            image = "buildpacksio/pack:latest"
                            workingDir = "/workspace/build"

                            command = [
                                "pack"
                                "build"
                                "$(params.REGISTRY_ENDPOINT)/$(params.REPO)/$(params.IMAGE):latest"
                                "--builder"
                                "gcr.io/buildpacks/builder:google-22"
                                "--workspace"
                                "/workspace/build"
                                "--docker-host=inherit"
                                "--publish"
                            ]

                            securityContext = {
                                privileged = True
                                runAsUser = 0
                                runAsGroup = 0
                                allowPrivilegeEscalation = True
                                capabilities.add = ["ALL"]
                            }

                            volumeMounts = [{
                                name = "docker-socket"
                                mountPath = "/var/run/docker.sock"
                            }]



                        }
                    ]
                    taskSpec.volumes = [
                        {
                            name = "docker-socket"
                            hostPath = {
                                path = "/var/run/docker.sock"
                                type = "Socket"
                            }
                        }
                    ]
                    workspaces = [
                        {name = "source", workspace = "source" }
                        {name = "build", workspace = "build" }
                    ]
                }
            ]
        }
        spec.workspaces = [
            {
                name = "build"
                subPath = "source"
                volumeClaimTemplate.spec = {
                    accessModes = [ "ReadWriteOnce" ]
                    resources.requests.storage = "1Gi"
                }
            }
            {
                name = "source"
                configMap.name = "{{ configmap_name }}"
            }
        ]
    }
  }

]
""", {
  function = r"${function}"
  function_name = r"${function_name}"
  function_namespace = r"${function_namespace}"
  configmap_name = r"${configmap_name}"
})
            }
        }
    ])
}

manifests.yaml_stream([
    makeContextXR()
#    makeUserXR()
#    makeHostXR()
])
