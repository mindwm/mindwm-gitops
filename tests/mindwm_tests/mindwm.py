import pytest

class test_namespace(): 
    def test_ns(self, kube):
        namespaces = kube.get_namespaces()
        ns = namespaces.get(self.namespace)
        assert ns is not None

    @pytest.mark.depends(on=['test_ns'])
    def test_deployment(self, kube):
        if hasattr(self, 'deployment'):
            deployments = kube.get_deployments(self.namespace)
            for deployment_name in self.deployment:
                deployment = deployments.get(deployment_name)
                assert deployment is not None,  f"Deployment '{deployment_name}' was not found in namespace '{self.namespace}'"

