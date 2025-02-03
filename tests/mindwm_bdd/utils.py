import pprint
import base64
import gzip
import json
import allure
import logging
from io import BytesIO
from kubernetes import client, config
from kubetest import condition
from kubetest import utils as kubetest_utils
import subprocess
import kubetest.objects.service 
import re
import asyncio
import json
import nats
import requests

logger = logging.getLogger(__name__)

def double_base64_decode(encoded_str):
    try:
        first_decode = base64.b64decode(encoded_str)
        second_decode = base64.b64decode(first_decode)
        return second_decode
    except base64.binascii.Error as e:
        logger.error(f"Base64 decoding error: {e}")
        return None

def gunzip_data(compressed_data):
    try:
        with gzip.GzipFile(fileobj=BytesIO(compressed_data)) as gz:
            decompressed_data = gz.read()
            return decompressed_data
    except OSError as e:
        logger.error(f"Gunzip error: {e}")
        return None


def helm_release_info(kube, release_name, namespace):
    # with allure.step(f"get helm release info for {release_name} in namespace {namespace}"):
    helm_secret = kube.get_secrets(namespace, labels = {"name": release_name})[f'sh.helm.release.v1.{release_name}.v1']
    #release_str = json.loads(helm_secret.obj.data)
    data_base64 = helm_secret.obj.data['release']
    data_str = gunzip_data(double_base64_decode(data_base64))
    data = json.loads(data_str)
    return data['info']

def helm_release_is_ready(kube, release_name, namespace):
    timeout = 300
    def is_ready():
        try:
            info = helm_release_info(kube, release_name, namespace)
            return info['status'] == "deployed"
        except Exception as e:
            logger.error(e)
            return False

    condition_name = f"wait for helm release {release_name} has status and info in {namespace}, timeout"
    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, is_ready),
                timeout=timeout, # More details in #118 github issue
                interval=5
            )
        except Exception as e:
            execute_and_attach_log(f"kubectl -n {namespace} get helmrelease")
            raise e


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
            
    status_condition = condition.Condition(f"argocd application '{ application_name }' has health and status in namespace '{ namespace }'", has_status)

    # 07:h8
    kubetest_utils.wait_for_condition(
        condition=status_condition,
        timeout=180,
        interval=5
    )

def statefulset_wait_for(kube, statefulset_name, namespace):
    timeout = 60
    def exists():
        try:
            statefulset = kube.get_statefulsets(namespace = namespace, fields = {'metadata.name': statefulset_name}).get(statefulset_name)
            if statefulset is None:
                return False
            return True
        except Exception as e:
            return False

    condition_name = f"Waiting for statefulset {statefulset_name} in {namespace} namespace, timeout = {timeout}"
    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, exists),
                timeout=timeout,
                interval=5
            )
        except Exception as e:
            execute_and_attach_log(f"kubectl -n {namespace} get statefulset")
            raise e
    return kube.get_statefulsets(namespace = namespace, fields = {'metadata.name': statefulset_name}).get(statefulset_name)

def knative_service_wait_for(kube, knative_service_name, namespace):
    return custom_object_wait_for(
            kube,  
            namespace,
            'serving.knative.dev',
            "v1",
            "services",
            knative_service_name,
            180
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
            logger.error(f"custom_object_wait_for:exists {e}")
            return False

    condition_name = f"Wait for {group}/{version} {plural} {name} exists in namespace {namespace}, timeout = {timeout}"
    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, exists),
                timeout=timeout,
                interval=5
            )
        except Exception as e:
            try:
                resource = client.CustomObjectsApi(kube.api_client).get_namespaced_custom_object(
                        group=group,
                        version=version,
                        plural=plural,
                        namespace = namespace,
                        name = name
                )
                allure.attach(json.dumps(resource, indent=4), name = f"resource", attachment_type='application/json')
            except Exception as resource_e:
                logger.error(resource_e)
                pass
            execute_and_attach_log(f"kubectl -n {namespace} get {plural}.{group}")
            raise e
        return client.CustomObjectsApi(kube.api_client).get_namespaced_custom_object(
                    group=group,
                    version=version,
                    plural=plural,
                    namespace = namespace,
                    name = name
                )

def custom_object_status_waiting_for(kube, namespace, group, version, plural, name, status_name, status, timeout):
    def status_equal():
        r = client.CustomObjectsApi(kube.api_client).get_namespaced_custom_object(
                group=group,
                version=version,
                plural=plural,
                namespace = namespace,
                name = name
            )
        assert (r is not None)
        if ("status" not in r):
            return False
        if ("conditions" not in r['status']):
            return False
        for condition in r['status']['conditions']:
            logger.info(f"check condition {condition}, type {condition['type']} == {status_name}")
            if condition['type'] == status_name:
                logger.info(f"MATCH condition {condition}, type {condition['type']} == {status_name}, status {condition['status']} == '{status}'")
                if condition['status'] == status:
                    return True
        return False

    resource = custom_object_wait_for(
        kube,
        namespace,
        group,
        version,
        plural,
        name,
        timeout
    )
    condition_name = f"Wait for {group}/{version} {plural} {name} state {status_name} equal {status} in namespace {namespace}, timeout = '{timeout}'"
    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, status_equal),
                timeout=timeout,
                interval=5
            )
        except Exception as e:
            try:
                resource = client.CustomObjectsApi(kube.api_client).get_namespaced_custom_object(
                        group=group,
                        version=version,
                        plural=plural,
                        namespace = namespace,
                        name = name
                )
                allure.attach(json.dumps(resource, indent=4), name = f"resource", attachment_type='application/json')
            except Exception as resource_e:
                logger.error(resource_e)
                pass
            execute_and_attach_log(f"kubectl -n {namespace} get {plural}.{group} {name}")
            raise e
    return client.CustomObjectsApi(kube.api_client).get_namespaced_custom_object(
            group=group,
            version=version,
            plural=plural,
            namespace = namespace,
            name = name
    )

def nats_stream_wait_for_ready(kube, nats_stream_name, namespace):
    def is_ready():
        try:
            nats_stream = nats_stream_wait_for(kube, nats_stream_name, namespace)
            pprint.pprint(nats_stream)
            is_ready = resource_get_condition(nats_stream['status'], 'Ready')
            return is_ready
        except Exception as e:
            return False

    ready_condition = condition.Condition(f"NatsJetStreamChannel {nats_stream_name} in ready state", is_ready)

    kubetest_utils.wait_for_condition(
        condition=ready_condition,
        timeout=180, # More details in #118 github issue
        interval=5
    )

    return nats_stream_wait_for(kube, nats_stream_name, namespace)
     
 
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
    

def get_lb(kube):
    services = kube.get_services("istio-system")
    lb_service = services.get("istio-ingressgateway")
    assert lb_service is not None
    lb_ip = lb_service.status().load_balancer.ingress[0].ip
    assert lb_ip is not None
    return lb_ip

def extract_trace_id(traceparent: str) -> str:
    # Define a regex pattern for the traceparent header
    traceparent_pattern = re.compile(
        r"^(?P<version>[0-9a-fA-F]{2})-"
        r"(?P<trace_id>[0-9a-fA-F]{32})-"
        r"(?P<span_id>[0-9a-fA-F]{16})-"
        r"(?P<trace_flags>[0-9a-fA-F]{2})$"
    )

    match = traceparent_pattern.match(traceparent)
    if not match:
        raise ValueError(f"Invalid traceparent format: '{traceparent}'")

    trace_id = match.group("trace_id")
    return trace_id

def get_service_name(span):
    return next(attr.value.string_value for attr in span.resource.attributes if attr.key == "service.name")

def span_by_service_name(traces, service_name):
    for span in traces.resource_spans:
        if get_service_name(span) == service_name:
            return span
    return None

def parse_resourceSpan(resourceSpan):
    return {
        "service_name": next(attr.value.string_value for attr in resourceSpan.resource.attributes if attr.key == "service.name"),
#        "http_code": next(attr.value.string_value for attr in resourceSpan.scope_spans[0].spans[0].attributes if attr.key == "http.status_code"),
#        "http_path": next(attr.value.string_value for attr in resourceSpan.scope_spans[0].spans[0].attributes if attr.key == "http.path")
        # context broker
    }
def deployment_wait_for(kube, deployment_name, namespace):
    timeout = 90
    def exists():
        try:
            deployment = kube.get_deployments(namespace = namespace, fields = {'metadata.name': deployment_name}).get(deployment_name)
            if deployment is None:
                return False
            return True
        except Exception as e:
            logger.error(e)
            return False

    condition_name = f"deployment {deployment_name} exists in {namespace} should exitst, timeout = {timeout}"

    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, exists),
                timeout=timeout,
                interval=5
            )
        except Exception as e:
            execute_and_attach_log(f"kubectl -n {namespace} get pods")
            execute_and_attach_log(f"kubectl -n {namespace} get deployment")

            raise e
    return kube.get_deployments(namespace = namespace, fields = {'metadata.name': deployment_name}).get(deployment_name)

def neo4j_get_bolt_node_port(kube, context_name):
    service = kube.get_services(namespace = f"context-{context_name}", labels = {"helm.neo4j.com/service": "neo4j"}).get(f"{context_name}-neo4j-neo4j")

    #k8s_svc = kubetest.objects.Service(service, kube.api_client)
    for port in service.obj.spec.ports:
        if port.name == 'tcp-bolt' and port.node_port is not None:
            return port.node_port
    
    return None

def ksvc_url(kube, namespace, knative_service_name):
    ksvc = custom_object_exists(
            kube,  
            namespace,
            'serving.knative.dev',
            "v1",
            "services",
            knative_service_name,
            60
            )
    return ksvc

async def nats_send(nats_url, nats_topic_name, event_headers, body):
    logger.info(f"Send {body} with headers {event_headers} to {nats_topic_name} on the {nats_url} server")
    nc = await nats.connect(nats_url)

    headers = {
        **{
            "datacontenttype": "application/json",
            # https://github.com/knative-extensions/eventing-natss/issues/518
            "ce-knativebrokerttl": "255",
        }, 
        **event_headers
    }

    # Publish with headers
    #nats_topic_name = "xxx"
    await nc.publish(nats_topic_name, body, headers = headers ) 

def custom_object_exists(kube, namespace, group, version, plural, name, timeout):
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
            logger.error(e)

            return False

    exists_condition = condition.Condition(f"Wait for {group}/{version} {plural} {name} exists in namespace {namespace}", exists)

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
    
def run_cmd(cmd, cwd):
    try:
        logger.debug(f"Execute command {cmd} in directory '{cwd}'")
        result = subprocess.run(["sh", "-c", cmd], check=True, text=True, capture_output=True, cwd=cwd)
        #print("Command Output:", result.stdout)
        if len(result.stdout.split("\n")) > 1:
            allure.attach(result.stdout, name = f"sdtout", attachment_type='text/plain')
        if len(result.stderr.split("\n")) > 1:
            allure.attach(result.stderr, name = f"stderr", attachment_type='text/plain')
        assert result.returncode == 0, f"Expected return code 0 but got {result.returncode}"
    except subprocess.CalledProcessError as e:
        logger.error(f"Error executing '{cmd}': {e}")
        raise e

def execute_and_attach_log(command):
    with allure.step(f"execute '{command}'"):
        try:
            result = subprocess.run(command, shell=True, text=True, capture_output=True, check=True)
            # for line in result.stdout.split("\n"):
            #     if (line == ""):
            #         continue
            #     logger.info(line)
            # for line in result.stderr.split("\n"):
            #     if (line == ""):
            #         continue
            #     logger.error(line)
            if len(result.stdout.split("\n")) > 1:
                allure.attach(result.stdout, name = f"sdtout", attachment_type='text/plain')
            if len(result.stderr.split("\n")) > 1:
                allure.attach(result.stderr, name = f"stderr", attachment_type='text/plain')
            return result
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed with exit code {e.returncode}: {e.stderr.strip()}")
        pass


def docker_image_exists(registry_url: str, image_name: str, tag: str) -> bool:
    try:
        response = requests.get(f"http://{registry_url}/v2/{image_name}/tags/list")
        answer = response.json()
        allure.attach(json.dumps(answer, indent=4), name = "registry reploy", attachment_type='application/json')
        # Fetch available tags

    except Exception as e:
        logger.error(f"Error checking image: {registry_url}/{image_name}:{tag}, error {e}")
        raise e

    assert(tag in answer["tags"]), f'No tag "{tag}" in {answer["tags"]}'

def cluster_custom_object_wait_for(kube, group, version, plural, name, timeout):
    def exists():
        try:
            api_instance = client.CustomObjectsApi(kube.api_client)
            api_instance.get_cluster_custom_object(
                group=group,
                version=version,
                plural=plural,
                name=name
            )
            return True
        except Exception as e:
            logger.debug(f"cluster_custom_objcet_wait_for exception {e}")
            return False

    condition_name = f"Wait for {group}/{version} {plural} {name} exists in cluster, timeout = {timeout}"
    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, exists),
                timeout=timeout,
                interval=5
            )
        except Exception as e:
            try:
                resource = client.CustomObjectsApi(kube.api_client).get_cluster_custom_object(
                        group=group,
                        version=version,
                        plural=plural,
                        name = name
                )
                allure.attach(json.dumps(resource, indent=4), name = f"resource", attachment_type='application/json')
            except Exception as resource_e:
                logger.error(resource_e)
                pass
            execute_and_attach_log(f"kubectl get {plural}.{group}")
            raise e
        return client.CustomObjectsApi(kube.api_client).get_cluster_custom_object(
                    group=group,
                    version=version,
                    plural=plural,
                    name = name
                )

def cluster_custom_object_status_waiting_for(kube, group, version, plural, name, status_name, status, timeout):
    def status_equal():
        r = client.CustomObjectsApi(kube.api_client).get_cluster_custom_object(
                group=group,
                version=version,
                plural=plural,
                name = name
            )
        assert (r is not None)
        if ("status" not in r):
            return False
        if ("conditions" not in r['status']):
            return False
        for condition in r['status']['conditions']:
            if condition['type'] == status_name:
                if condition['status'] == status:
                    return True
        return False

    resource = cluster_custom_object_wait_for(
        kube,
        group,
        version,
        plural,
        name,
        timeout
    )
    condition_name = f"Wait for {group}/{version} {plural} {name} state {status_name} equal {status} in cluster, timeout = {timeout}"
    with allure.step(condition_name):
        try:
            kubetest_utils.wait_for_condition(
                condition=condition.Condition(condition_name, status_equal),
                timeout=timeout,
                interval=5
            )
        except Exception as e:
            try:
                resource = client.CustomObjectsApi(kube.api_client).get_cluster_custom_object(
                        group=group,
                        version=version,
                        plural=plural,
                        name = name
                )
                allure.attach(json.dumps(resource, indent=4), name = f"resource", attachment_type='application/json')
            except Exception as resource_e:
                logger.error(resource_e)
                pass
            execute_and_attach_log(f"kubectl get {plural}.{group} {name}")
            raise e
    return client.CustomObjectsApi(kube.api_client).get_cluster_custom_object(
            group=group,
            version=version,
            plural=plural,
            name = name
    )
