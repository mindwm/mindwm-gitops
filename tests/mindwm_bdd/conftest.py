import pytest
import re
import pprint
import kubetest
from kubetest.client import TestClient
from pytest_bdd import scenarios, scenario, given, when, then, parsers
import re
from typing import List

@scenario('kubernetes.feature','Validate Mindwm custom resource definitions')
def test_scenario():
    assert False

@pytest.fixture 
def test_env():
    return {}

@given(".*kubernetes cluster$")
def kubernetes_cluster(kube, clusterinfo):
    assert(clusterinfo.cluster), f"{clusterinfo} "

@then("all nodes in the kubernetes are ready")
def kubernetes_nodes(kube):
    for node in kube.get_nodes().values():
        assert(node.is_ready()), f"{node.name} is not ready"


@scenario('kubernetes.feature','Validate Mindwm custom resource definitions')
@given('Mindwm environment')
def mindwm_environment(kube):
    for plural in ["xcontexts", "xhosts", "xusers"]:
        kube.get_custom_objects(group = 'mindwm.io', version = 'v1beta1', plural = plural, all_namespaces = True)
    pass

@then("create mindwm context with name {context_name}")
def mindwm_context(kube, context_name):
    pass



def pytest_collection_modifyitems(config: pytest.Config, items: List[pytest.Item]):
    # XXX workaround
    for item in items:
        item.add_marker(pytest.mark.namespace(create = False, name = "default"))
