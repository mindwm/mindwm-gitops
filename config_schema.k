import regex
import manifests

userPrefix = "user"
contextPrefix = "context"
hostPrefix = "host"

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
crossplaneResourceName = lambda entity: any, resourceName : ResourceNameStr -> str {
    getData(entity.name) + "-" + getData(resourceName)
}

crossplane_user2context_trigger_name = lambda user : MindwmUser, ctx: MindwmContext -> str {
  "user-" + getData(user.name) + "-to-context-" + getData(ctx.name)
} 

crossplane_context2user_trigger_name = lambda user : MindwmUser, ctx: MindwmContext -> str {
  "context-" + getData(ctx.name) + "-to-user-" + getData(user.name)
} 

domain: DomainStr { data = "mindwm.local" }

schema Mindwm2:
    context: MindwmContext
    user: MindwmUser
    host: MindwmHost

schema MindwmHost:
    name: ResourceNameStr
    broker: Broker { name.data = "${getData(name)}-host-broker"}
    # from host_broker to user broker trigger
    trigger: Trigger { name.data = "${getData(name)}-trigger-to-user-broker" }
    # from user_broker to host broker trigger
    trigger_back: Trigger {
      name.data = "user-broker-to-" + getData(name) + "-broker-trigger"
    } 

schema MindwmUser:
    name: ResourceNameStr
    namespace: ResourceNameStr = { data = "${userPrefix}-${getData(name)}" }
    broker: Broker { name.data = "user-broker" }

schema MindwmContext:
    name: ResourceNameStr
    namespace: ResourceNameStr = { data = "${contextPrefix}-${getData(name)}" }
    broker: Broker { 
      name.data = "context-broker"
      virtual_service = {
        name.data = getData(name) + "-virtual-service"
      } 
    } 
    kafka: Kafka {}
    neo4j: Neo4j {}
    vector: Vector {}
    cdc_topic: KafkaTopic { 
      name.data = "context-" + getData(name) + "-cdc"
    } 
    gateway: IstioGateway { 
      name.data = "gateway" 
      hosts = [
        "neo4j." + getData(name) + "." + getData(domain)
      ] 
    } 
    neo4j_virtual_service: IstioVirtualService {
      name.data = "neo4j-virtual-service"
    } 
    kafkaSource: KafkaSource = {
        name.data = getData(cdc_topic.name) + "-kafkasource"
        topicName = cdc_topic.name
        bootstrap_servers = [ "${getData(kafka.cluster_name)}.${getData(kafka.namespace)}:${kafka.port}" ]
    }
    io_context: KnativeFunction {
        name.data = "iocontext"
        image = "ghcr.io/mindwm/knfunc-io-context:latest"
    }
    kafka_cdc: KnativeFunction {
        name.data = "kafka-cdc"
        image = "ghcr.io/mindwm/knfunc-kafka-cdc:latest"
    }
    pong: KnativeFunction {
        name.data = "pong"
        image = "ghcr.io/mindwm/knfunc-pong:latest"
    }

schema KafkaTopic:
    name: ResourceNameStr

schema Broker:
    name: ResourceNameStr
    configMapName: ResourceNameStr = (lambda brokerName : ResourceNameStr -> ResourceNameStr {
        { data = "${getData(brokerName)}-config" }
    })(name)
    deadLetter: DeadLetter { name.data = "dead-letter" }
    virtual_service?: IstioVirtualService 

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
    bootstrap_servers: [str] = [
       getData(cluster_name) + "." + getData(namespace) + ":" + str(port)
    ]


schema Neo4j:
    name: ResourceNameStr = { data = "neo4j" }
    version: str = "4.4.33"
    username: str = "neo4j"
    password: str = "password"
    plugin_pvc_name: ResourceNameStr = { data = "neo4j-plugins" }
    pvc_size: str = "5Gi"
    port: int = 7687

schema Vector:
    name: ResourceNameStr = { data = "vector" }

schema Crossplane:
    apiVersion: str = "apiextensions.crossplane.io/v1"
    compositeVersion: str = "v1beta1"
    domain: DomainStr { data = "mindwm.io" }

schema IstioGateway:
    name: ResourceNameStr 
    hosts: [str]

schema IstioVirtualService:
    name: ResourceNameStr

schema KnativeFunction:
    name: ResourceNameStr 
    image: str
ctx = MindwmContext { name.data = "pinkj" }
