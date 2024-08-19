import regex
import manifests

userPrefix = "user"
contextPrefix = "context"

schema ResourceNameStr:
    data: str
    check:
        regex.match(data, r'^[a-z0-9]([-a-z0-9]*[a-z0-9])?$')
        len(data) < 64
schema DomainStr:
    data: str
    check:
        regex.match(data, "")

getData = lambda resourceStr : any -> str {
    resourceStr.data
}
crossplaneResourceName = lambda ctx: MindwmContext, resourceName : str -> str {
    "${getData(ctx.name)}-${resourceName}"
}


schema Mindwm:
    domain: DomainStr { data = "mindwm.local" }
    context: MindwmContext
    user: MindwmUser
    host: MindwmHost

schema MindwmHost:
    name: ResourceNameStr
    broker: Broker { name.data = "${getData(name)}-host-broker"}
    trigger: Trigger { name.data = "${getData(name)}-trigger-to-user-broker" }

schema MindwmUser:
    name: ResourceNameStr
    namespace: ResourceNameStr = { data = "${userPrefix}-${getData(name)}" }
    broker: Broker { name.data = "user-broker" }
    deadLetter: DeadLetter { name.data = "dead-letter" }

schema MindwmContext:
    name: ResourceNameStr
    namespace: ResourceNameStr = { data = "${contextPrefix}-${getData(name)}" }
    broker: Broker { name.data = "context-broker"}
    deadLetter: DeadLetter { name.data = "dead-letter" }
    kafka: Kafka {}
    neo4j: Neo4j {}
    vector: Vector {}
    kafkaSource: KafkaSource = {
        name.data = "cdc-topic"
        topicName.data = "${getData(name)}-cdc-topic"
        bootstrap_servers = [ "${getData(kafka.cluster_name)}.${getData(kafka.namespace)}:${kafka.port}" ]
    }
    crossplane_pvc_name: ResourceNameStr = (lambda -> ResourceNameStr {
        { data = "${getData(name)}-${neo4j.pvc}" }
    })()
    crossplane_neo4j_name: ResourceNameStr = (lambda -> ResourceNameStr {
        { data = "${getData(name)}-${getData(neo4j.name)}" }
    })()
    crossplane_vector_name: ResourceNameStr = (lambda -> ResourceNameStr {
        { data = "${getData(name)}-${getData(vector.name)}" }
    })()


schema Broker:
    name: ResourceNameStr
    configMapName = (lambda brokerName : ResourceNameStr -> ResourceNameStr {
        { data = "${getData(brokerName)}-config" }
    })(name)

schema DeadLetter:
    name: ResourceNameStr
    image: str = "gcr.io/knative-releases/knative.dev/eventing/cmd/event_display"

schema Trigger:
    name: ResourceNameStr

schema KafkaSource:
    name: ResourceNameStr
    topicName: ResourceNameStr
    bootstrap_servers: [str]

schema Kafka:
    namespace: ResourceNameStr = { data = "redpanda" }
    port: int = 9093
    cluster_name: ResourceNameStr = { data = "neo4j-cdc" }

schema Neo4j:
    name: ResourceNameStr = { data = "neo4j" }
    version: str = "4.4.33"
    username: str = "neo4j"
    password: str = "password"
    pvc: str = "neo4j-plugins"
    pvc_size: str = "5Gi"

schema Vector:
    name: ResourceNameStr = { data = "vector" }

schema Crossplane:
    apiVersion: str = "apiextensions.crossplane.io/v1"
    compositeVersion: str = "v1beta1"
    domain: DomainStr { data = "mindwm.io" }


config = Mindwm {
    context = {
        name = ResourceNameStr { data = "green"}
    }
    host.name = ResourceNameStr { data = "laptop" }
    user.name = ResourceNameStr { data = "alice" }
}

manifests.yaml_stream([
    crossplaneResourceName(config.context, "xxx")
])
