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
  }
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = "neo4j-plugins-pvc"
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
    metadata.name = "neo4j"
    spec = {
      forProvider = {
        chart = {
          name = "${charts.neo4j.name}"
          repository = "${charts.neo4j.repoURL}"
          version = "${config.config.neo4j_version}"
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
            neo4j.password = "${config.config.neo4j_password}"
            services.neo4j.spec.type = "NodePort"
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
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLRun"
                spec.source = template.execute("""user_name = option("params").oxr.spec.name
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = "user-configmap-{{ user_name }}"
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "v1"
          kind = "ConfigMap"
          metadata.name = "user-configmap-{{ user_name }}"
          metadata.namespace = "default"
          data = {
            foo = "bar"
          }
        }
      }
    }
  }
]
""", {
    user_name = r"${user_name}"
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
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLRun"
                spec.source = template.execute("""host_name = option("params").oxr.spec.name
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = "host-configmap-{{ host_name }}"
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "v1"
          kind = "ConfigMap"
          metadata.name = "host-configmap-{{ host_name }}"
          metadata.namespace = "default"
          data = {
            foo = "bar"
          }
        }
      }
    }
  }
]
""", {
    host_name = r"${host_name}"
    kafka_cdc_topic_name = r"${kafka.mkContextCdcTopicName($context_name)}"
})
            }
        }
    ])
}

#manifests.yaml_stream([
#    makeContextXR()
#    makeUserXR()
#    makeHostXR()
#])
