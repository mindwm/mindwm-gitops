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
                assert deployment.is_ready() is not False,  f"Deployment '{deployment_name}' is not ready in '{self.namespace}'"

    @pytest.mark.depends(on=['test_ns'])
    def test_statefulset(self, kube):
        if hasattr(self, 'statefulset'):
            statefulsets = kube.get_statefulsets(self.namespace)
            for statefulset_name in self.statefulset:
                statefulset = statefulsets.get(statefulset_name)
                assert statefulset is not None, f"Statefulset '{statefulset_name}' was not found in namespace '{self.namespace}'"
                assert statefulset.is_ready() is not False,  f"Statefulset '{statefulset_name}' is not ready in '{self.namespace}'"
