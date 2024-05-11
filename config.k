import mindwm.schema as MindwmSchema

kafka = {
    cluster_name = "neo4j-cdc"
    namespace = "redpanda"
    port = 9093
    brokerEndpoint = cluster_name + "." + namespace + ":${port}"
} 

kafka_cluster_name = "neo4j-cdc"
kafka_port = 9003
neo4j_version = "4.4.33"
neo4j_password = "password"
crossplane = {
    namespace = "crossplane-system"
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

config = {
    kafka_cluster_name = "neo4j-cdc"
    kafka_port = 9003
    neo4j_version = "4.4.33"
    neo4j_password = "password"
    crossplane = {
        namespace = "crossplane-system"
    }
}
