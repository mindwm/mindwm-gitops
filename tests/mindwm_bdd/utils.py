import pprint
import base64
import gzip
import json
from io import BytesIO
from kubernetes import client, config

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
    helm_secret = kube.get_secrets(namespace, labels = {"name": release_name})['sh.helm.release.v1.argocd.v1']
    #release_str = json.loads(helm_secret.obj.data)
    data_base64 = helm_secret.obj.data['release']
    data_str = gunzip_data(double_base64_decode(data_base64))
    data = json.loads(data_str)
    return data['info']

def argocd_application_exists(kube, application_name, namespace):
    api_instance = client.CustomObjectsApi(kube.api_client)
    resource = api_instance.get_namespaced_custom_object(
        group='argoproj.io',
        version='v1alpha1',
        plural='applications',
        namespace = namespace,
        name = application_name
    )
    return resource
