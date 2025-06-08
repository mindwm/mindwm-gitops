mindwm_domain = "mindwm.local"


sources = {
  mindwm_ns = "org.mindwm"
  func_ns = "knfunc"
  knfunc_action = lambda user_name host_name {
    hostname = "%" if host_name == "" else host_name
    "${sources.mindwm_ns}.${sources.func_ns}.%.%.{{ user_name }}.{{ host_name }}.tmux.%.%.action"
  }
}

kafka = {
    cluster_name = "neo4j-cdc"
    namespace = "redpanda"
    port = 9093
    brokerEndpoint = cluster_name + "." + namespace + ":${port}"
    mkContextCdcTopicName = lambda context_name : str {
        context_name + "-cdc-topic"
    }
}

argocd = {
  release_name = "argocd"
  gateway_name = "argocd-gateway"
  namespace = "argocd"
  url = "argocd.${mindwm_domain}"
  virtual_service = "argocd-vs"
  destination = lambda {
    "${argocd.release_name}-server.${argocd.namespace}.svc.cluster.local"
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
        trigger_back = lambda user_name : str -> str {
          "trigger-context-to-user" + delimiter + user_name
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
        trigger_back = lambda host_name : str -> str {
            "trigger-knative-to-host-" + delimiter + host_name
        }
    }

    context = {
        istio_gateway = lambda context_name : str - >str {
          "context-${context_name}-gateway"
        }
        neo4j_vs_name = lambda context_name : str -> str {
          "${context_name}-neo4j-ui"
        }
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
        version = "1.18.0"
    }
    eventing = {
        namespace = "knative-eventing"
        version = "1.18.0"
    }
}

node_red = {
  helm_chart_version = "0.34.0"
}

cert_manager = {
  helm_chart_version = "1.17.2"
  namespace = "cert-manager"
}

istio = {
    version = "1.26.0"
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
  gateway_name = "${namespace}-gateway"
  otel_collector = {
    release_name = "otel-collector"
  }
  loki = {
    url = "loki.${mindwm_domain}"
    release_name = "loki"
    virtual_service = "loki-vs"
    destination = lambda {
        "${monitoring.loki.release_name}-gateway"
    }
  }
  tempo = {
    url = "tempo.${mindwm_domain}"
    virtual_service = "tempo-vs"
    release_name = "tempo"
    destination = lambda {
      "tempo"
    }
  }
  grafana = {
    url = "grafana.${mindwm_domain}"
    virtual_service = "grafana-vs"
    destination = lambda {
      "${monitoring.victoria_metrics.release_name}-grafana"
    }
  }
  victoria_metrics = {
    release_name = "vm-aio"
    url = "vm.${mindwm_domain}"
    virtual_service = "vm-vs"
    destination = lambda {
      #"${monitoring.victoria_metrics.release_name}.${monitoring.namespace}.svc.cluster.local"
      "vmsingle-${monitoring.victoria_metrics.release_name}-victoria-metrics-k8s-stack.${monitoring.namespace}.svc.cluster.local"
    }
  }
  promtail = {
    release_name = "promtail"
    chart_version = "6.17.0"
  }
  zipkin_endpoint = lambda tempo_release_name : str, monitoring_ns : str {
    "http://${tempo_release_name}.${monitoring_ns}:9411/api/v2/spans"
  }
  prometheus_endpoint = lambda {
    "http://vmsingle-${monitoring.victoria_metrics.release_name}-victoria-metrics-k8s-stack.${monitoring.namespace}:8429"
  }
  opencensus_endpoint = lambda tempo_release_name : str, monitoring_ns : str {
    "${tempo_release_name}.${monitoring_ns}:55678"
  }
  traces_endpoint = lambda tempo_release_name : str, monitoring_ns : str {
    "http://${tempo_release_name}.${monitoring_ns}:4317/v1/traces"
  }
  loki_endpoint = lambda {
    "http://${monitoring.loki.release_name}.${monitoring.namespace}:3100/otlp"
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
    version = "4.4.42"
    username = "neo4j"
    password = "password"
    release_name = "neo4j"
    port = 7687
    http_port = 7474

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

zot = {
    chart_version = "0.1.68"
    release_name = "zot"
    namespace = "zot"
}
