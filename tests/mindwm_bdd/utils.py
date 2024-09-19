import pprint
import base64
import gzip
import json
from io import BytesIO
from kubernetes import client, config
from kubetest import condition
from kubetest import utils as kubetest_utils

def double_base64_decode(encoded_str):
    try:
        first_decode = base64.b64decode(encoded_str)
        second_decode = base64.b64decode(first_decode)
        return second_decode
    except base64.binascii.Error as e:
        print(f"Base64 decoding error: {e}")
        return None

def gunzip_data(compressed_data):
    try:
        with gzip.GzipFile(fileobj=BytesIO(compressed_data)) as gz:
            decompressed_data = gz.read()
            return decompressed_data
    except OSError as e:
        print(f"Gunzip error: {e}")
        return None


def helm_release_info(kube, release_name, namespace):
    helm_secret = kube.get_secrets(namespace, labels = {"name": release_name})[f'sh.helm.release.v1.{release_name}.v1']
    #release_str = json.loads(helm_secret.obj.data)
    data_base64 = helm_secret.obj.data['release']
    data_str = gunzip_data(double_base64_decode(data_base64))
    data = json.loads(data_str)
    return data['info']

def helm_release_is_ready(kube, release_name, namespace):
    def is_ready():
        try:
            info = helm_release_info(kube, release_name, namespace)
            return info['status'] == "deployed"
        except Exception as e:
            return False

    ready_condition = condition.Condition("helm release has status and info", is_ready)

    kubetest_utils.wait_for_condition(
        condition=ready_condition,
        timeout=180,
        interval=5
    )


    return helm_release_info(kube, release_name, namespace)


    
def argocd_application(kube, application_name, namespace):
    api_instance = client.CustomObjectsApi(kube.api_client)
    resource = api_instance.get_namespaced_custom_object(
        group='argoproj.io',
        version='v1alpha1',
        plural='applications',
        namespace = namespace,
        name = application_name
        )
    return resource

def argocd_application_wait_status(kube, application_name, namespace):
    def has_status(): 
        try:
            resource = argocd_application(kube, application_name, namespace),
            sync_status = resource[0]['status']['sync']
            health_status = resource[0]['status']['health']['status']
            return True
        except Exception as e: 
            return False
            
    status_condition = condition.Condition("api object deleted", has_status)

    # 07:h8
    kubetest_utils.wait_for_condition(
        condition=status_condition,
        timeout=180,
        interval=5
    )

def statefulset_wait_for(kube, statefulset_name, namespace):
    def exists():
        try:
            statefulset = kube.get_statefulsets(namespace = namespace, fields = {'metadata.name': statefulset_name}).get(statefulset_name)
            return True
        except Exception as e:
            pprint.pprint(e)
            return False

    exists_condition = condition.Condition("statefulset exists", exists)

    kubetest_utils.wait_for_condition(
        condition=exists_condition,
        timeout=60,
        interval=5
    )
    return kube.get_statefulsets(namespace = namespace, fields = {'metadata.name': statefulset_name}).get(statefulset_name)

def knative_service_wait_for(kube, knative_service_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'serving.knative.dev',
            "v1",
            "services",
            knative_service_name,
            60
            )

def custom_object_wait_for(kube, namespace, group, version, plural, name, timeout):
    def exists():
        try:
            api_instance = client.CustomObjectsApi(kube.api_client)
            resource = api_instance.get_namespaced_custom_object(
                group=group,
                version=version,
                plural=plural,
                namespace = namespace,
                name = name
            )
            return True
        except Exception as e:
            return False

    exists_condition = condition.Condition(f"Wait for {group}/{version} {name} exists in namespace {namespace}", exists)

    kubetest_utils.wait_for_condition(
        condition=exists_condition,
        timeout=timeout,
        interval=5
    )
    return client.CustomObjectsApi(kube.api_client).get_namespaced_custom_object(
                group=group,
                version=version,
                plural=plural,
                namespace = namespace,
                name = name
            )

def knative_trigger_wait_for(kube, knative_trigger_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'eventing.knative.dev',
            "v1",
            "triggers",
            knative_trigger_name,
            60
            )

def knative_broker_wait_for(kube, knative_broker_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'eventing.knative.dev',
            "v1",
            "brokers",
            knative_broker_name,
            60
            )

def kafka_topic_wait_for(kube, kafka_topic_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'cluster.redpanda.com',
            "v1alpha2",
            "topics",
            kafka_topic_name,
            180
            )

def kafka_source_wait_for(kube, kafka_source_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'sources.knative.dev',
            "v1beta1",
            "kafkasources",
            kafka_source_name,
            180
            )

def nats_stream_wait_for(kube, nats_stream_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'messaging.knative.dev',
            "v1alpha1",
            "natsjetstreamchannels",
            nats_stream_name,
            120
            )

def custom_object_plural_wait_for(kube, group, version, plural):
    def exists():
        try:
            kube.get_custom_objects(group = group, version = version, plural = plural, all_namespaces = True)
            return True
        except Exception as e:
            return False

    exists_condition = condition.Condition(f"Wait for custom object {group}/{version} {plural} exists", exists)

    kubetest_utils.wait_for_condition(
        condition=exists_condition,
        timeout=60,
        interval=5
    )
    return kube.get_custom_objects(group = group, version = version, plural = plural, all_namespaces = True)




def resource_get_condition(status, condition_type):
    for condition in status['conditions']:
        if condition.get('type') == condition_type:
            match_condition = condition    

    # XXX
    return match_condition.get('status')
    
