import pprint
from kubernetes import client, config
import kubernetes.client.exceptions as kube_exceptions
from kubetest.objects.customresourcedefinition import CustomResourceDefinition
from kubetest.utils import wait_for_condition, Condition
from context import MindwmContext


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

def context_get(kube, context_name):
    api_instance = client.CustomObjectsApi(kube.api_client)
    resource = api_instance.get_namespaced_custom_object(
        group='mindwm.io',
        version='v1beta1',
        plural='contexts',
        namespace = "default",
        name = context_name 
    )
    #resourceObject = CustomResourceDefinition(resource)
    #pprint.pprint(resourceObject)
    #CustomResourceDefinition(resource)
    return MindwmContext(resource, group = 'mindwm.io', crd=None, version = 'v1beta', plural = 'contexts')



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
    pprint.pprint(f"context_validate == {status}")

    for condition in status.get('conditions'):
        if condition.get('type') == 'Ready':
            ready_condition = condition
        if condition.get('type') == 'Synced':
            synced_condition = condition

    is_ready = ready_condition and ready_condition.get('status') == 'True'
    is_synced = synced_condition and synced_condition.get('status') == 'True'
    assert(is_synced), f"Context {context_name} is not synced"
    assert(is_ready), f"Context {context_name} is not ready"
