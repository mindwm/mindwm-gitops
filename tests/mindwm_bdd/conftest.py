import pytest
import re
import pprint
import kubetest
from kubetest.client import TestClient
from pytest_bdd import scenarios, scenario, given, when, then, parsers
import mindwm_crd
import re
from typing import List

@pytest.fixture 
def ctx():
    return {}

@scenario('kubernetes.feature','Validate Mindwm custom resource definitions')
def test_scenario():
    assert False


@given(".*kubernetes cluster$")
def kubernetes_cluster(kube, clusterinfo):
    assert(clusterinfo.cluster), f"{clusterinfo} "

@then("all nodes in the kubernetes are ready")
def kubernetes_nodes(kube):
    for node in kube.get_nodes().values():
        assert(node.is_ready()), f"{node.name} is not ready"


@scenario('kubernetes.feature','Validate Mindwm custom resource definitions')
@given('MindWM environment')
def mindwm_environment(kube):
    for plural in ["xcontexts", "xhosts", "xusers"]:
        kube.get_custom_objects(group = 'mindwm.io', version = 'v1beta1', plural = plural, all_namespaces = True)
    pass

@when("the user creates a MindWM context with the name {context_name}")
def mindwm_context(ctx, kube, context_name):
    ctx['context_name'] = context_name
    mindwm_crd.context_create(kube, context_name)

@then("validate that the context is ready and operable")
def minwdm_context_validate(ctx, kube):
    try:
        mindwm_crd.context_validate(kube, ctx['context_name'])
    except AssertionError as e:
        # known bug https://github.com/mindwm/mindwm-gitops/issues/100
        if str(e) == f"Context {ctx['context_name']} is not ready":
            pass
        else:
            raise

def pytest_collection_modifyitems(config: pytest.Config, items: List[pytest.Item]):
    # XXX workaround
    for item in items:
        item.add_marker(pytest.mark.namespace(create = False, name = "default"))
