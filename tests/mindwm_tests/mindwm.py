#import pytest

class test_namespace(): 
    def test_ns(self, kube):
        namespaces = kube.get_namespaces()
        ns = namespaces.get(self.namespace)
        assert ns is not None
