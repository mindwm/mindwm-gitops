import yaml
import file
import json_merge_patch as p
import .config as config
import ..config as mindwm

yaml_file_merge = lambda filename : str, patch : any {
    p.merge(yaml.decode_all(file.read(filename)), patch)
}

makeKafkaCluster = lambda name : str {
    cluster = yaml.decode_all(file.read("redpanda/cluster.yaml"))
    p.merge(cluster, {
        metadata.name = name
    })
} 

makeKafkaTopic = lambda name : str {
    yaml_file_merge("redpanda/topic.yaml", {
        metadata.name = mindwm.makeKafkaTopicName(name)
        spec = {
            kafkaApiSpec.brokers = [ "${mindwm.config.kafka_clustser_name}.${config.redpanda.namespace}:${mindwm.config.kafka_port}" ]

            partitions = 1
            replicationFactor = 1
        }

    })
} 
