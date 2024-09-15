import pprint
from kubernetes import client, config

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

def context_create(kube, context_name):
    new_context = context_crd
    new_context['metadata']['name'] = new_context["spec"]["name"] = context_name
    api_instance = client.CustomObjectsApi(kube.api_client)

    resources = api_instance.list_namespaced_custom_object(
        group='mindwm.io',
        version='v1beta1',
        plural='contexts',
        namespace = "default",
    )
    assert not any(item['metadata']['name'] == context_name for item in resources.get('items', [])), f"Context {context_name} already exists"
    api_response = api_instance.create_namespaced_custom_object(
        group=api_group,
        version=api_version,
        namespace="default",
        plural="contexts",
        body=new_context
    )

def context_validate(kube, context_name):
    api_instance = client.CustomObjectsApi(kube.api_client)

    resources = api_instance.list_namespaced_custom_object(
        group='mindwm.io',
        version='v1beta1',
        plural='contexts',
        namespace = "default",
    )
    assert any(item['metadata']['name'] == context_name for item in resources.get('items', [])), f"Context {context_name} doesn't exists"



def context_delete(kube, context_name):
    pass
