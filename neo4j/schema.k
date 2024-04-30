import ..util as util
import ..config as mindwm
import ..redpanda.schema as kafka

neo4j_image_name = "neo4j"

makeNeo4jReleaseValues = lambda context_name : str {
    kafkaTopic = mindwm.makeKafkaTopicName(context_name)
    util.yaml_file_merge("./neo4j/helm_values.yaml", {
        env = {        
            NEO4J_kafka_bootstrap_servers = kafka.makeKafkaBrokerStr(context_name)
            "NEO4J_streams_source_topic_nodes_${kafkaTopic}" = '*'
            "NEO4J_streams_source_topic_relationships_${kafkaTopic}" = '*'
        } 
        image.customImage: "${neo4j_image_name}:$mmindwm.config.neo4j_version{}"
    })
    
} 

