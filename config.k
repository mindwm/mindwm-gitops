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


config = {
    kafka_clustser_name = "neo4j-cdc"
}
