kafka = {
    cluster_name = "neo4j-cdc"
    namespace = "redpanda"
    port = 9093
    brokerEndpoint = cluster_name + "." + namespace + ":${port}"
    mkContextCdcTopicName = lambda context_name : str {
        context_name + "-cdc-topic"
    }
}

knativeBroker = {
    deadLetterImage = "gcr.io/knative-releases/knative.dev/eventing/cmd/event_display"
}

contextBroker = {
    name = lambda context_name : str {
        "context-broker" + delimiter + context_name
    }
    configMapName = lambda context_name : str {
        name(context_name) + delimiter + "configmap"
    }
    kafkaSourceName = lambda context_name : str {
        name(context_name) + delimiter + "source"

    }
    deadLetterName = lambda context_name : str {
        name(context_name) + delimiter + "dead-letter"
    }
}


Mindwm = {
    user = {
        namespace = lambda username : str -> str {
            "user-" + username
        }
        broker = {
            configmap = lambda user_name : str -> str {
                "user" + delimiter + user_name + delimiter + "broker-configmap"
            }
            name = lambda user_name : str -> str {
                "user" + delimiter + user_name + delimiter + "broker"
            }
        }
        deadLetter = {
            name = lambda user_name : str -> str {
                "user" + delimiter + user_name + delimiter + "dead-letter"
            }
        }
        contextTrigger = {
            name = lambda context_name : str -> str {
                "trigger-user-broker-to" + delimiter + context_name
            }
            crossplane_name = lambda user_name : str, context_name : str -> str {
                "trigger" + delimiter + user_name + delimiter + "broker-to" + delimiter + context_name
            }
        }
    }
    host = {
        broker = {
            configmap = lambda host_name : str -> str {
                host_name + delimiter + "broker-configmap"
            }
            name = lambda host_name : str -> str {
                host_name + delimiter + "broker"
            }
        }
        trigger = lambda host_name : str -> str {
            # FIXME (@metacoma)
            # host trigger name = "trigger-{host_name}-broker-to-user-broker
            "trigger-host-broker-to" + delimiter + host_name
        }
    }

    context = {
        io_context = {
            name = "io-context"
            crossplane_name = lambda context_name : str -> str {
                 context_name + delimiter + "io-context"
            }
            crossplane_trigger = lambda context_name : str -> str {
                 context_name + delimiter + "io-context-trigger"
            }

            image = "ghcr.io/mindwm/io-context:latest"
        }
        touch = {
            name = "mindwm-touch"
            crossplane_name = lambda context_name : str -> str {
                 context_name + delimiter + "mindwm-touch"
            }
            crossplane_trigger = lambda context_name : str -> str {
                 context_name + delimiter + "mindwm-touch-trigger"
            }

            image = "ghcr.io/mindwm/mindwm-touch:latest"
        }
    }
}

knative = {
    serving = {
        namespace = "knative-serving"
    }
    eventing = {
        namespace = "knative-eventing"
    }
}

istio = {
    version = "1.21.1"
    system = {
        namespace = "istio-system"
    }
    gateway = {
        namespace = "istio-system"
    }
    pilot = {
        cpu_req = "200m"
    }
}

kafka_cluster_name = "neo4j-cdc"
kafka_port = 9003
#neo4j_version = "4.4.33"
#neo4j_password = "password"
crossplane = {
    namespace = "crossplane-system"
}

monitoring = {
  namespace = "monitoring"
  otel_collector = {
    release_name = "otel-collector"
  } 
  loki = {
    release_name = "loki"
  } 
  tempo = {
    release_name = "tempo"
  } 
  victoria_metrics = {
    release_name = "vm-aio"
  } 
} 

delimiter = "-"

contextNamespacePrefix = "context"
userNamespacePrefix = "team"

makeUserNamespace = lambda username : str {
    userNamespacePrefix + delimiter + username
}

makeContextNamespace = lambda ns_name : str {
    contextNamespacePrefix + delimiter + ns_name
}

makeKafkaTopicName = lambda context_name : str {
    "context" + delimiter + context_name + delimiter + "cdc"
}

neo4j = {
    version = "4.4.33"
    username = "neo4j"
    password = "password"
    release_name = "neo4j"
    port = 7687

    crossplane_pvc_name = lambda context_name : str -> str {
        context_name + delimiter + "neo4j-plugin-pvc"
    }

    crossplane_name = lambda context_name : str -> str {
        context_name + delimiter + "neo4j"
    }
}

vector = {
    image = {
        repo = "ghcr.io/mindwm/vector-image/vector-image"
        tag = "main"
    } 
    chart_version = "0.33.0"
    crossplane_name = lambda context_name : str -> str {
        context_name + delimiter + "vector"
    }
} 

config = {
    kafka_cluster_name = "neo4j-cdc"
    kafka_port = 9003
    crossplane = {
        namespace = "crossplane-system"
    }
}

