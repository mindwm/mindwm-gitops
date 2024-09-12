import kubernetes_utils
import kubernetes
import yaml
import json
import time
import logging
import pprint
from kubernetes import client
from kubetest.objects.api_object import ApiObject
from kubetest.client import TestClient
from kubetest.condition import Condition
from kubetest.utils import wait_for_condition

#log = logging.getLogger("kubetest")

class MindwmContext():
    manifest = kubernetes_utils.load_file("context.yaml")
    def __init__(self, context_name: str, namespace: str = "default"): 
        self.manifest['metadata']['name'] = context_name
        self.manifest['spec']['name'] = context_name
        self.context_namespace = f"context-{context_name}"
        self.namespace = namespace
        self.name = context_name
    def create(self):
        pprint.pprint(self.manifest)
        kubernetes_utils.apply_simple_item(self.manifest)
    def delete(self):
        print("Delete")
        kubernetes_utils.delete_simple_item(self.manifest)

    def status(self):
        api_version = self.manifest.get("apiVersion")
        kind = self.manifest.get("kind")
        resource_name = self.manifest.get("metadata").get("name")
        kubernetes.config.load_kube_config()
        dynamic_client = kubernetes.dynamic.DynamicClient(
            kubernetes.client.api_client.ApiClient()
        )
        crd_api = dynamic_client.resources.get(api_version=api_version, kind=kind)
        try:
            crd_api.get(namespace=self.namespace, name=resource_name)
            crd_resource = crd_api.get(namespace=self.namespace, name=resource_name)
            sync_status = [item for item in crd_resource.status.conditions if item['reason'] == 'ReconcileSuccess']
            return json.loads(sync_status[0].status.lower())
        except kubernetes.dynamic.exceptions.NotFoundError: 
            print("Not found")
            raise  
        return False
        
