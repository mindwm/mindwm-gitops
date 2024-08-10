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
                kind = "KCLRun"
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.source = template.execute("""${kcl_util_func}
context_name = option("params").oxr.spec.name
kafkaTopicName = kafka.mkContextCdcTopicName("{{ context_name }}")
items = [
  {
    apiVersion = "v1"
    kind = "Namespace"
    metadata.name = makeContextNamespace("{{ context_name }}")
    metadata.labels = {
        "istio-injection" = "enabled"
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = neo4j.crossplane_pvc_name("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "v1"
        kind = "PersistentVolumeClaim"
        metadata.name = "neo4j-plugins"
        metadata.namespace = makeContextNamespace("{{ context_name }}")
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
    metadata.name = kafkaTopicName
    spec.forProvider.manifest = {
        apiVersion = "cluster.redpanda.com/v1alpha1"
        kind = "Topic"
        metadata = {
            name = kafkaTopicName
            namespace = "${config.kafka.namespace}"
        }
        spec = {
            partitions = 1
            replicationFactor = 1
            additionalConfig = {
                "cleanup.policy" = "compact"
            }
            kafkaApiSpec.brokers = [
                "${config.kafka.brokerEndpoint}"
            ]
        }

    }
  }
  {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata.name = neo4j.crossplane_name("{{ context_name }}")
    spec = {
      forProvider = {
        chart = {
          name = "${charts.neo4j.name}"
          repository = "${charts.neo4j.repoURL}"
          version = "${config.neo4j.version}"
        }
        namespace = makeContextNamespace("{{ context_name }}")
        values = {
            additionalVolumeMounts = [
                {
                    mountPath = "/var/lib/neo4j/plugins"
                    name = "neo4j-plugins"
                }
            ]
            additionalVolumes = [
                {
                    name = "neo4j-plugins"
                    persistentVolumeClaim.claimName = "neo4j-plugins"
                }
            ]
            env = {
                "NEO4J_apoc_export_file_enabled" = "true"
                "NEO4J_apoc_import_file_enabled" = "true"
                "NEO4J_apoc_import_file_use__neo4j__config" = "true"
                "NEO4J_dbms_logs_debug_level" = "DEBUG"
                "NEO4J_kafka_bootstrap_servers" = "${config.kafka.brokerEndpoint}"
                "NEO4J_streams_source_topic_nodes_{{ kafkaTopicName }}" = "*"
                "NEO4J_streams_source_topic_relationships_{{ kafkaTopicName }}" = '*'
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
            podSpec.initContainers = [
                {
                    image = "curlimages/curl:8.6.0"
                    name = "install-apoc-plugin"
                    user = "root"
                    volumeMounts = [{
                        mountPath = "/var/lib/neo4j/plugins"
                        name = "neo4j-plugins"
                    }]
                    workingDir = "/var/lib/neo4j/plugins"
                    command = [
                        "curl",
                        "--retry"
                        "3"
                        "-Lo"
                        "apoc.jar"
                        "--no-clobber"
                        "https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/4.4.0.23/apoc-4.4.0.23-all.jar"
                    ]
                }
                {
                    image = "curlimages/curl:8.6.0"
                    name = "install-neo4j-stream-plugin"
                    user = "root"
                    workingDir = "/var/lib/neo4j/plugins"
                    volumeMounts = [{
                        mountPath = "/var/lib/neo4j/plugins"
                        name = "neo4j-plugins"
                    }]
                    command = [
                        "curl",
                        "--retry"
                        "3"
                        "-Lo"
                        "streams.jar"
                        "--no-clobber"
                        "https://github.com/neo4j-contrib/neo4j-streams/releases/download/4.1.3/neo4j-streams-4.1.3.jar"
                    ]
                }
            ]

        }
      }
    }
  }
  {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata.name = vector.crossplane_name("{{ context_name }}")
    spec = {
      forProvider = {
        chart = {
          name = "${charts.vector.name}"
          repository = "${charts.vector.repoURL}"
          version = "${config.vector.chart_version}"
        }
        namespace = makeContextNamespace("{{ context_name }}")
        values = {
            image = {
                # TODO(@metacoma) parametrize
                repository = "${config.vector.image.repo}"
                tag = "${config.vector.image.tag}"
            }
            service.enabled = False
            serviceHeadless.enalbed = False
            podLabels = {
                "sidecar.istio.io/inject" = "false"
            }
            customConfig = {
                transforms = {
                    cloudevent = {
                        type = "lua"
                        version = "2"
                        inputs = ["neo4j-cdc"]
                        hooks = {
                            process = "process"
                            init = "seed_init"
                        }
                        source = '''\
        function seed_init()
          uuid = require("uuid")
          local socket = require("socket")  -- gettime() has higher precision than os.time()
          uuid.seed()
        end
        function process(event, emit)
          local cloudevent = {}
          cloudevent.log = {
            id = uuid(),
            data = event.log,
            source = "graph." .. event.log["payload"]["type"] ,
            specversion = "1.0",
            datacontenttype = "application/json",
            type = event.log["meta"]["operation"],
            time = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time()),

            traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
            tracestate = "rojo=00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01,congo=lZWRzIHRoNhcm5hbCBwbGVhc3VyZS4"
          }
          if (cloudevent.log.type == "created") then
            if (event.log["payload"]["type"] == "node") then
              if event.log["payload"]["after"]["labels"] then
                cloudevent.log["subject"] = table.concat(event.log["payload"]["after"]["labels"], ",")
                else
                  cloudevent.log["subject"] = "unknown_node"
              end
            end
            if (event.log["payload"]["type"] == "relationship") then
              if (event.log["payload"]["label"]) then
                  cloudevent.log["subject"] = event.log["payload"]["label"]
                else
                  cloudevent.log["subject"] = "unknown_relationship"
              end
            end
          end
          emit(cloudevent)
        end
'''
                    }
                }
                sources = {
                    "neo4j-cdc" = {
                        type = "kafka"
                        bootstrap_servers: "${config.kafka.brokerEndpoint}"
                        group_id = "{{ context_name }}-vector"
                        topics = [ "{{ context_name }}-cdc-topic" ]
                        decoding.codec = "json"

                        librdkafka_options = {
                            "api.version.request" = 'true'
                            "partition.assignment.strategy" = "roundrobin"
                            "log_level" = "6"
                            "session.timeout.ms" = "10000"
                            "max.poll.interval.ms" = "300000"
                            "socket.nagle.disable" = "false"
                            "socket.keepalive.enable" = "true"
                            "socket.max.fails" = "3"
                            "fetch.min.bytes" = "1000000"
                        }

                    }
                }
                sinks = {
                    console = {
                        type = "console"
                        inputs = [ "neo4j-cdc" ]
                        encoding.codec = "json"
                    }
                    "context-broker" = {
                        type = "http"
                        inputs = [ "cloudevent" ]
                        encoding.codec = "json"
                        method = "post"
                        batch = {
                            max_size = 1
                            max_events = 1
                        }
                        framing.method = "newline_delimited"
                        uri = "http://broker-ingress.${config.knative.eventing.namespace}.svc.cluster.local/" +  makeContextNamespace("{{ context_name }}") + "/" + contextBroker.name("{{ context_name }}")
                        request = {
                            concurrency = 1
                            headers = {
                                "Content-Type" = "application/cloudevents+json"
                            }
                        }
                    }
                }
            }
        }
      }
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = contextBroker.configMapName("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = {
            name = contextBroker.configMapName("{{ context_name }}")
            namespace = makeContextNamespace("{{ context_name }}")
        }
        data = {
            "channel-template-spec" = '''
apiVersion: messaging.knative.dev/v1
kind: InMemoryChannel
'''
        }

    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = contextBroker.name("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Broker"
        metadata = {
            name = contextBroker.name("{{ context_name }}")
            namespace = makeContextNamespace("{{ context_name }}")
            annotations = {
                "eventing.knative.dev/broker.class" = "MTChannelBasedBroker"
            }
        }
        spec.config = {
            apiVersion = "v1"
            kind = "ConfigMap"
            name = contextBroker.configMapName("{{ context_name }}")
        }

    }
  }
  # kafkaSource
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = contextBroker.kafkaSourceName("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "sources.knative.dev/v1beta1"
        kind = "KafkaSource"
        metadata = {
            name = contextBroker.kafkaSourceName("{{ context_name }}")
            namespace = makeContextNamespace("{{ context_name }}")
        }
        spec = {
            bootstrapServers = [ "${config.kafka.brokerEndpoint}" ]
            consumerGroup = "knative-group"
            sink.ref = {
                apiVersion = "eventing.knative.dev/v1"
                kind = "Broker"
                name = contextBroker.name("{{ context_name }}")
            }
            topics = [ "{{ kafkaTopicName }}" ]
        }

    }
  }
  # deadLetter service
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = contextBroker.deadLetterName("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "serving.knative.dev/v1"
        kind = "Service"
        metadata = {
            name = contextBroker.deadLetterName("{{ context_name }}")
            namespace = makeContextNamespace("{{ context_name }}")
        }
        spec.template.spec.containers = [{
            image = "${config.knativeBroker.deadLetterImage}"
        }]

    }
  }

  # io_context
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.context.io_context.crossplane_name("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "serving.knative.dev/v1"
        kind = "Service"
        metadata = {
            name = "${config.Mindwm.context.io_context.name}"
            namespace = makeContextNamespace("{{ context_name }}")
        }
        spec.template.metadata.annotations = {
            "autoscaling.knative.dev/enable-scale-to-zero" = "false"
        }
        spec.template.spec.containers = [{
            env = [
                {
                    name = "NEO4J_URL"
                    value = "{{ context_name }}-${config.neo4j.release_name}-neo4j." + makeContextNamespace("{{ context_name }}") + ":${config.neo4j.port}"
                }
                {
                    name = "NEO4J_USERNAME"
                    value = "${config.neo4j.username}"
                }
                {
                    name = "NEO4J_PASSWORD"
                    value = "${config.neo4j.password}"
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
            image = "${config.Mindwm.context.io_context.image}"
        }]

    }
  }

  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.context.io_context.crossplane_trigger("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Trigger"
        metadata = {
            name = "${config.Mindwm.context.io_context.name}-trigger"
            namespace = makeContextNamespace("{{ context_name }}")
        }
        spec = {
            broker = contextBroker.name("{{ context_name }}")
            delivery = {
                deadLetterSink.ref = {
                    apiVersion = "serving.knative.dev/v1"
                    kind = "Service"
                    name = contextBroker.deadLetterName("{{ context_name }}")
                }
            }
            filters = [
                {
                    "any" = [
                        { exact.type = "iodocument" }
                    ]
                }
            ]
            subscriber.ref = {
                apiVersion = "serving.knative.dev/v1"
                kind = "Service"
                name = "${config.Mindwm.context.io_context.name}"
                namespace = makeContextNamespace("{{ context_name }}")
            }
        }
    }
  }

  # touch
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.context.touch.crossplane_name("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "serving.knative.dev/v1"
        kind = "Service"
        metadata = {
            name = "${config.Mindwm.context.touch.name}"
            namespace = makeContextNamespace("{{ context_name }}")
        }
        spec.template.metadata.annotations = {
            "autoscaling.knative.dev/enable-scale-to-zero" = "false"
        }
        spec.template.spec.containers = [{
            env = [
                {
                    name = "NEO4J_URL"
                    value = "{{ context_name }}-${config.neo4j.release_name}-neo4j." + makeContextNamespace("{{ context_name }}") + ":${config.neo4j.port}"
                }
                {
                    name = "NEO4J_USERNAME"
                    value = "${config.neo4j.username}"
                }
                {
                    name = "NEO4J_PASSWORD"
                    value = "${config.neo4j.password}"
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
            image = "${config.Mindwm.context.touch.image}"
        }]

    }
  }

  # touch trigger
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.context.touch.crossplane_trigger("{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Trigger"
        metadata = {
            name = "${config.Mindwm.context.touch.name}-trigger"
            namespace = makeContextNamespace("{{ context_name }}")
        }
        spec = {
            broker = contextBroker.name("{{ context_name }}")
            delivery = {
                deadLetterSink.ref = {
                    apiVersion = "serving.knative.dev/v1"
                    kind = "Service"
                    name = contextBroker.deadLetterName("{{ context_name }}")
                }
            }
            filters = [
                {
                    exact.type = "touch"
                }
            ]
            subscriber.ref = {
                apiVersion = "serving.knative.dev/v1"
                kind = "Service"
                name = "${config.Mindwm.context.touch.name}"
                namespace = makeContextNamespace("{{ context_name }}")
            }
        }
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.context.istio_gateway
    spec.forProvider.manifest = {
      apiVersion = "networking.istio.io/v1beta1"
      kind = "Gateway"
      metadata = {
          name = "${config.Mindwm.context.istio_gateway}"
          namespace = makeContextNamespace("{{ context_name }}")
      }
      spec = {
        selector.istio = "ingressgateway"
        servers = [
          {
            port = {
              number = 80
              name = "http"
              protocol = "HTTP"
            }
            hosts = [ "neo4j.{{ context_name }}.${config.mindwm_domain}" ]
          } 
        ]
      }
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.context.neo4j_vs_name
    spec.forProvider.manifest = {
      apiVersion = "networking.istio.io/v1beta1"
      kind = "VirtualService"
      metadata = {
          name = "${config.Mindwm.context.neo4j_vs_name}"
          namespace = makeContextNamespace("{{ context_name }}")
      }
      spec = {
        hosts = [ "neo4j.{{ context_name }}.${config.mindwm_domain}" ]
        gateways = [ "${config.Mindwm.context.istio_gateway}" ]
        http = [
          {
            match = [
              {
                uri.prefix = "/"
              }
            ]
            route = [{
              destination.host = "{{ context_name }}-${config.neo4j.release_name}-neo4j.context-{{ context_name }}.svc.cluster.local"
              destination.port.number = int("${config.neo4j.http_port}")
            }]

          }
        ]
      }
    }
  }

]
""", {
    context_name = r"${context_name}"
    kafkaTopicName = r"${kafkaTopicName}"
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
                kind = "KCLRun"
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.source = template.execute("""${kcl_util_func}
user_name = option("params").oxr.spec.name
context_names = option("params").oxr.spec.context
items = [
  {
    apiVersion = "v1"
    kind = "Namespace"
    metadata.name = Mindwm.user.namespace("{{ user_name }}")
    metadata.labels = {
        "istio-injection" = "enabled"
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.user.broker.configmap("{{ user_name }}")
    spec.forProvider.manifest = {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = {
            name = Mindwm.user.broker.configmap("{{ user_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
        }
        data = {
            "channel-template-spec" = '''
apiVersion: messaging.knative.dev/v1
kind: InMemoryChannel
'''
        }
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.user.broker.name("{{ user_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Broker"
        metadata = {
            name = Mindwm.user.broker.name("{{ user_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
            annotations = {
                "eventing.knative.dev/broker.class" = "MTChannelBasedBroker"
            }
        }
        spec.config = {
            apiVersion = "v1"
            kind = "ConfigMap"
            name = Mindwm.user.broker.configmap("{{ user_name }}")
        }

    }
  }

  # deadLetter service
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.user.deadLetter.name("{{ user_name }}")
    spec.forProvider.manifest = {
        apiVersion = "serving.knative.dev/v1"
        kind = "Service"
        metadata = {
            name = Mindwm.user.deadLetter.name("{{ user_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
        }
        spec.template.spec.containers = [{
            image = "${config.knativeBroker.deadLetterImage}"
        }]

    }
  }
] + [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.user.contextTrigger.crossplane_name("{{ user_name }}","{{ context_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Trigger"
        metadata = {
            name = Mindwm.user.contextTrigger.name("{{ context_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
        }
        spec = {
            broker = Mindwm.user.broker.name("{{ user_name }}")
            delivery = {
                deadLetterSink.ref = {
                    apiVersion = "serving.knative.dev/v1"
                    kind = "Service"
                    name = Mindwm.user.deadLetter.name("{{ user_name }}")
                }
            }
            filters = [
                {
                    "any" = [
                        { exact.type = "iodocument" }
                        { exact.type = "touch" }
                    ]
                }
            ]
            subscriber.ref = {
                apiVersion = "eventing.knative.dev/v1"
                kind = "Broker"
                name = contextBroker.name("{{ context_name }}")
                namespace = makeContextNamespace("{{ context_name }}")
            }
        }
    }
  }
  for context_name in context_names
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
                kind = "KCLRun"
                # TODO (@metacoma) add kcl_util_func to template data in mk function
                spec.source = template.execute("""${kcl_util_func}
host_name = option("params").oxr.spec.name
user_name = option("params").oxr.spec.username
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.host.broker.configmap("{{ host_name }}")
    spec.forProvider.manifest = {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = {
            name = Mindwm.host.broker.configmap("{{ host_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
            labels = {
                "eventing.knative.dev/release" = "devel"
            }
        }
        data = {
            "channelTemplateSpec" = '''
apiVersion: messaging.knative.dev/v1alpha1
kind: NatsJetStreamChannel
spec:
  stream:
    config:
      additionalSubjects:
        - "mindwm.{{ user_name }}.{{ host_name }}.>"
      overrideName: {{ host_name }}
'''
        }
    }
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.host.broker.name("{{ host_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Broker"
        metadata = {
            name = Mindwm.host.broker.name("{{ host_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
            annotations = {
                "eventing.knative.dev/broker.class" = "MTChannelBasedBroker"
            }
        }
        spec.config = {
            apiVersion = "v1"
            kind = "ConfigMap"
            name = Mindwm.host.broker.configmap("{{ host_name }}")
        }

    }
  }

  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = Mindwm.host.trigger("{{ host_name }}")
    spec.forProvider.manifest = {
        apiVersion = "eventing.knative.dev/v1"
        kind = "Trigger"
        metadata = {
            name = Mindwm.host.trigger("{{ host_name }}")
            namespace = Mindwm.user.namespace("{{ user_name }}")
        }
        spec = {
            broker = Mindwm.host.broker.name("{{ host_name }}")
            delivery = {
                deadLetterSink.ref = {
                    apiVersion = "serving.knative.dev/v1"
                    kind = "Service"
                    name = Mindwm.user.deadLetter.name("{{ user_name }}")
                }
            }
            filters = [
                {
                    "any" = [
                        { exact.type = "iodocument" }
                        { exact.type = "touch" }
                    ]
                }
            ]
            subscriber.ref = {
                apiVersion = "eventing.knative.dev/v1"
                kind = "Broker"
                name = Mindwm.user.broker.name("{{ user_name }}")
                namespace = Mindwm.user.namespace("{{ user_name }}")
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

manifests.yaml_stream([
#    makeContextXR()
#    makeUserXR()
    makeHostXR()
])
