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
        contextTrigger = lambda context_name : str -> str {
            "trigger-user-broker-to" + delimiter + context_name
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
            image = "metacoma/knative-neomodel:latest"
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
}

kafka_cluster_name = "neo4j-cdc"
kafka_port = 9003
#neo4j_version = "4.4.33"
#neo4j_password = "password"
crossplane = {
    namespace = "crossplane-system"
} 


prometheus = {
    namespace = "prometheus"
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
} 

kiali_operator = {
    namespace = "kiali-operator"
    release_name = "kiali-operator"
} 

config = {
    kafka_cluster_name = "neo4j-cdc"
    kafka_port = 9003
    crossplane = {
        namespace = "crossplane-system"
    }
}
