import pprint
from kubernetes import client, config
import kubernetes.client.exceptions as kube_exceptions
from kubetest.objects.customresourcedefinition import CustomResourceDefinition
from kubetest.utils import wait_for_condition, Condition
from context import MindwmContext
from user import MindwmUser
from host import MindwmHost


api_group = "mindwm.io"
api_version = "v1beta1"

context_crd = {
    "apiVersion": f"{api_group}/{api_version}",
    "kind": "Context",
    "metadata": {
        "name": "context_name"
    },
    "spec": {
        "name": "context_name"
    }   
}

user_crd = {
    "apiVersion": "mindwm.io/v1beta1",
    "kind": "User",
    "metadata": {
        "name": "${USER}"
    },
    "spec": {
        "context": ["${CONTEXT_NAME}"],
        "name": "${USER}"
    }
}

host_crd = {
    "apiVersion": "mindwm.io/v1beta1",
    "kind": "Host",
    "metadata": {
        "name": "${HOST}"
    },
    "spec": {
        "name": "${HOST}",
        "username": "${USER}"
    }
}


def context_get(kube, context_name):
    api_instance = client.CustomObjectsApi(kube.api_client)
    resource = api_instance.get_namespaced_custom_object(
        group='mindwm.io',
        version='v1beta1',
        plural='contexts',
        namespace = "default",
        name = context_name 
    )
    return MindwmContext(resource, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'contexts')

def user_get(kube, user_name):
    api_instance = client.CustomObjectsApi(kube.api_client)
    resource = api_instance.get_namespaced_custom_object(
        group='mindwm.io',
        version='v1beta1',
        plural='users',
        namespace = "default",
        name = user_name 
    )
    return MindwmUser(resource, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'users')

def host_get(kube, host_name):
    api_instance = client.CustomObjectsApi(kube.api_client)
    resource = api_instance.get_namespaced_custom_object(
        group='mindwm.io',
        version='v1beta1',
        plural='hosts',
        namespace = "default",
        name = host_name 
    )
    return MindwmHost(resource, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'hosts')


def context_create(kube, context_name):
    new_context = context_crd
    new_context['metadata']['name'] = new_context["spec"]["name"] = context_name
    try:
        context = context_get(kube, context_name)
        assert context is None, f"Context {context_name} is already exists"
    except kube_exceptions.ApiException: # 404
        pass
    
    api_instance = client.CustomObjectsApi(kube.api_client)

    api_response = api_instance.create_namespaced_custom_object(
        group=api_group,
        version=api_version,
        namespace="default",
        plural="contexts",
        body=new_context
    )
    return MindwmContext(api_response, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'contexts')


def context_validate(kube, context_name):
    try:
        context = context_get(kube, context_name)
    except kube_exceptions.ApiException:
        assert False, f"Context {context_name} not found in cluster"
    context.wait_for_status()

    status = context.status()

    for condition in status.get('conditions'):
        if condition.get('type') == 'Ready':
            ready_condition = condition
        if condition.get('type') == 'Synced':
            synced_condition = condition

    is_ready = ready_condition and ready_condition.get('status') == 'True'
    is_synced = synced_condition and synced_condition.get('status') == 'True'
    assert(is_synced), f"Context {context_name} is not synced"
    assert(is_ready), f"Context {context_name} is not ready"



def user_create(kube, user_name, context_name):
    new_user = user_crd
    new_user['metadata']['name'] = new_user["spec"]["name"] = user_name
    new_user["spec"]["context"][0] = context_name 
    try:
        user = user_get(kube, user_name)
        assert user is None, f"User {user_name} is already exists"
    except kube_exceptions.ApiException: # 404
        pass
    
    api_instance = client.CustomObjectsApi(kube.api_client)

    api_response = api_instance.create_namespaced_custom_object(
        group=api_group,
        version=api_version,
        namespace="default",
        plural="users",
        body=new_user
    )
    return MindwmUser(api_response, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'users')

def host_create(kube, host_name, user_name):
    new_host = host_crd
    new_host['metadata']['name'] = new_host["spec"]["name"] = host_name
    new_host["spec"]["username"] = user_name
    try:
        host = host_get(kube, host_name)
        assert host is None, f"User {host_name} is already exists"
    except kube_exceptions.ApiException: # 404
        pass
    
    api_instance = client.CustomObjectsApi(kube.api_client)

    api_response = api_instance.create_namespaced_custom_object(
        group=api_group,
        version=api_version,
        namespace="default",
        plural="hosts",
        body=new_host
    )
    return MindwmUser(api_response, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'hosts')
