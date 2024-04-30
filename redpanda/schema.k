import yaml
import file
import json_merge_patch as p

makeKafkaCluster = lambda name : str {
    cluster = yaml.decode_all(file.read("redpanda/cluster.yaml"))
    p.merge(cluster, {
        metadata.name = name
    })
} 
