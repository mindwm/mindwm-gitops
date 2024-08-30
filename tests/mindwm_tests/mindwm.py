import pytest
import pprint

class test_namespace(): 
    def test_ns(self, kube):
        namespaces = kube.get_namespaces()
        ns = namespaces.get(self.namespace)
        assert ns is not None, f"Namespace '{namespace}' was not found in namespaces"

    @pytest.mark.depends(on=['test_ns'])
    def test_deployment(self, kube):
        if hasattr(self, 'deployment'):
            deployments = kube.get_deployments(self.namespace)
            for deployment_name in self.deployment:
                deployment = deployments.get(deployment_name)
                assert deployment is not None,  f"Deployment '{deployment_name}' was not found in namespace '{self.namespace}'"
                status = deployment.status()
                replicas = status.replicas
                ready_replicas = status.ready_replicas
                assert replicas == ready_replicas,  f"Deployment '{deployment_name}' status is not True in '{self.namespace}', {replicas} != {ready_replicas}"

    @pytest.mark.depends(on=['test_ns'])
    def test_statefulset(self, kube):
        if hasattr(self, 'statefulset'):
            statefulsets = kube.get_statefulsets(self.namespace)
            for statefulset_name in self.statefulset:
                statefulset = statefulsets.get(statefulset_name)
                assert statefulset is not None, f"Statefulset '{statefulset_name}' was not found in namespace '{self.namespace}'"
                assert statefulset.is_ready() is not False,  f"Statefulset '{statefulset_name}' is not ready in '{self.namespace}'"
    @pytest.mark.depends(on=['test_ns', 'test_statefulset', 'test_deployment'])
    def test_service(self, kube):
        if hasattr(self, 'service'):
            services = kube.get_services(self.namespace)
            for service_name in self.service:
                service = services.get(service_name)
                assert service is not None, f"Service '{service_name}' was not found in namespace '{self.namespace}'"
