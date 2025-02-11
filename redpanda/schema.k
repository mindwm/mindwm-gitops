import ..config as config
#import ..config as mindwm
import ..util as util


makeKafkaCluster = lambda name : str {
    util.yaml_file_merge("redpanda/cluster.yaml", {
        metadata.name = name
    })
} 

makeKafkaBroker = lambda name : str {
   [ "${config.kafka.kafka_clustser_name}.${config.redpanda.namespace}:${config.kafka.port}" ]
} 

makeKafkaBrokerStr = lambda name : str {
    makeKafkaBroker(name)[0] # TODO (@metacoma) join(",")
} 

makeKafkaTopic = lambda name : str {
    util.yaml_file_merge("redpanda/topic.yaml", {
        metadata.name = config.makeKafkaTopicName(name)
        spec = {
            kafkaApiSpec.brokers = makeKafkaBroker(name)

            partitions = 1
            replicationFactor = 1
        }

    })
} 
