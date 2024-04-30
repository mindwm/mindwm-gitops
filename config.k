import mindwm.schema as MindwmSchema

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
    kafka_clustser_name = "neo4j-cdc"
    kafka_port = 9003
    neo4j_version = "4.4.28"
}
