import pathlib
import yaml
import kubernetes
import time
import yaml
import pprint
import json

kubernetes.config.load_kube_config()
DYNAMIC_CLIENT = kubernetes.dynamic.DynamicClient(
    kubernetes.client.api_client.ApiClient()
)

def apply_simple_item(dynamic_client: kubernetes.dynamic.DynamicClient, manifest: dict, verbose: bool=False):
    api_version = manifest.get("apiVersion")
    kind = manifest.get("kind")
    resource_name = manifest.get("metadata").get("name")
    namespace = "default"
    crd_api = dynamic_client.resources.get(api_version=api_version, kind=kind)

    try:
        crd_api.get(namespace=namespace, name=resource_name)
        crd_api.patch(body=manifest, content_type="application/merge-patch+json")
        if verbose:
            print(f"{namespace}/{resource_name} patched")
        return crd_api
    except kubernetes.dynamic.exceptions.NotFoundError:
        crd_api.create(body=manifest, namespace=namespace)
        if verbose:
            print(f"{namespace}/{resource_name} created")
        return crd_api

def delete_simple_item(dynamic_client: kubernetes.dynamic.DynamicClient, manifest: dict, verbose: bool=False):
    api_version = manifest.get("apiVersion")
    kind = manifest.get("kind")
    resource_name = manifest.get("metadata").get("name")
    namespace = "default"  
    crd_api = dynamic_client.resources.get(api_version=api_version, kind=kind)
    crd_api.get(namespace=namespace, name=resource_name)

    try:
        crd_api.delete(namespace = "default", name = resource_name)
    except:
        print("Error")

        

def apply_simple_item_from_yaml(dynamic_client: kubernetes.dynamic.DynamicClient, filepath: pathlib.Path, verbose: bool=False):
    with open(filepath, 'r') as f:
        manifest = yaml.safe_load(f)
        apply_simple_item(dynamic_client=dynamic_client, manifest=manifest, verbose=verbose)

def load_file(filepath: str):
    with open(filepath, "r") as f:
        return yaml.safe_load(f)

def wait_for_namespace(kube, ns_name):
    namespaces = kube.get_namespaces({"metadata.name": ns_name})
    if len(namespaces) != 1:
        return False
    namespace = namespaces.get(ns_name)
    if namespace is None:
        return False
    return True

def wait_for_namespace_is_ready(kube, ns_name):
    namespaces = kube.get_namespaces({"metadata.name": ns_name})
    namespace = namespaces.get(ns_name)
    return namespace.is_ready()

def wait_for_broker(kube, broker_name, namespace):
    api_version = "eventing.knative.dev/v1"
    kind = "Broker"
    resource_name = broker_name
    namespace = namespace
    crd_api = DYNAMIC_CLIENT.resources.get(api_version=api_version, kind=kind)
    try:
        crd_api.get(namespace=namespace, name=resource_name)
        return True
    except kubernetes.dynamic.exceptions.NotFoundError:
        return False

def wait_for_broker_is_ready(kube, broker_name, namespace):
    api_version = "eventing.knative.dev/v1"
    kind = "Broker"
    resource_name = broker_name
    namespace = namespace
    crd_api = DYNAMIC_CLIENT.resources.get(api_version=api_version, kind=kind)
    broker = crd_api.get(namespace=namespace, name=resource_name)
    pprint.pprint(broker.status)

    for status_type in ['Addressable','EventPoliciesReady', 'TriggerChannelReady', 'FilterReady', 'Ready']:

        status = [item for item in broker.status.conditions if item['type'] == status_type]
        assert len(status) == 1 
        if not json.loads(status[0].status.lower()):
            return False

    return True

def wait_for_kafka_source(kube, kafka_source_name, namespace):
    api_version = "sources.knative.dev/v1beta1"
    kind = "KafkaSource"
    resource_name = kafka_source_name 
    namespace = namespace
    crd_api = DYNAMIC_CLIENT.resources.get(api_version=api_version, kind=kind)
    try:
        crd_api.get(namespace=namespace, name=resource_name)
        return True
    except kubernetes.dynamic.exceptions.NotFoundError:
        return False



def wait_for_kafka_source_is_ready(kube, kafka_source_name, namespace):
    api_version = "sources.knative.dev/v1beta1"
    kind = "KafkaSource"
    resource_name = kafka_source_name 
    namespace = namespace
    crd_api = DYNAMIC_CLIENT.resources.get(api_version=api_version, kind=kind)
    resource = crd_api.get(namespace=namespace, name=resource_name)
    pprint.pprint(resource.status)

    for status_type in ['ConsumerGroup', 'SinkProvided', 'Ready']:
        status = [item for item in resource.status.conditions if item['type'] == status_type]
        assert len(status) == 1, status_type
        if not json.loads(status[0].status.lower()):
            return False

    return True

def wait_for_resource(kube, resourceSpec, namespace):
    crd_api = DYNAMIC_CLIENT.resources.get(api_version=resourceSpec['apiVersion'], kind=resourceSpec['kind'])
    try:
        crd_api.get(namespace=namespace, name=resourceSpec['name'])
        return True
    except kubernetes.dynamic.exceptions.NotFoundError:
        return False

def wait_for_resource_is_ready(kube, resourceSpec, namespace):
    crd_api = DYNAMIC_CLIENT.resources.get(api_version=resourceSpec['apiVersion'], kind=resourceSpec['kind'])
    resource = crd_api.get(namespace=namespace, name=resourceSpec['name'])
    for status_type in resourceSpec['status_types']:
        status = [item for item in resource.status.conditions if item['type'] == status_type]
        assert len(status) == 1, status_type
        if not json.loads(status[0].status.lower()):
            return False

    return True

def wait_for_function_deployment(kube, name, namespace):
    deployments = kube.get_deployments(namespace, labels = {'serving.knative.dev/service': name})
    return bool(len(deployments))
