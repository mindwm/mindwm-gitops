import pytest
import re
import pprint
import kubetest
from kubetest.client import TestClient
from kubernetes import client
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


@scenario('mindwm_crd.feature','Validate Mindwm custom resource definitions')
def test_mindwm():
    return True

@given('a MindWM environment')
def mindwm_environment(kube):
    for plural in ["xcontexts", "xhosts", "xusers"]:
        kube.get_custom_objects(group = 'mindwm.io', version = 'v1beta1', plural = plural, all_namespaces = True)
    pass

@when("God creates a MindWM context with the name \"{context_name}\"")
def mindwm_context(ctx, kube, context_name):
    ctx['context_name'] = context_name
    mindwm_crd.context_create(kube, context_name)

@then("the context should be ready and operable")
def minwdm_context_validate(ctx, kube):
    try:
        mindwm_crd.context_validate(kube, ctx['context_name'])
    except AssertionError as e:
        # known bug https://github.com/mindwm/mindwm-gitops/issues/100
        if str(e) == f"Context {ctx['context_name']} is not ready":
            pass
        else:
            raise

@when("God creates a MindWM user resource with the name \"{user_name}\" and connects it to the context \"{context_name}\"")
def mindwm_user_create(ctx, kube, user_name, context_name):
    ctx['user_name'] = user_name
    mindwm_crd.user_create(kube, user_name, context_name)

@then("the user resource should be ready and operable")
def mindwm_user_validate(ctx, kube):
    user = mindwm_crd.user_get(kube, ctx['user_name'])
    try:
        user.validate()
    except AssertionError as e:
        # known bug https://github.com/mindwm/mindwm-gitops/issues/100
        if str(e) == f"User {ctx['user_name']} is not ready":
            pass
        else:
            raise

@when("God creates a MindWM host resource with the name \"{host_name}\" and connects it to the user \"{user_name}\"")
def mindwm_host_create(ctx, kube, host_name, user_name):
    ctx['host_name'] = host_name
    mindwm_crd.host_create(kube, host_name, user_name)

@then("the host resource should be ready and operable")
def mindwm_host_validate(ctx, kube):
    host_name = ctx['host_name']
    host = mindwm_crd.host_get(kube, host_name)
    try:
        host.validate()
    except AssertionError as e:
        # known bug https://github.com/mindwm/mindwm-gitops/issues/100
        if str(e) == f"Host {ctx['host_name']} is not ready":
            pass
        else:
            raise

@when("God deletes the MindWM host resource \"{host_name}\"")
def mindwm_host_delete(kube, host_name):
    host = mindwm_crd.host_get(kube, host_name)
    return host.delete(None)

@then("the host \"{host_name}\" should be deleted")
def mindwm_host_deleted(kube, host_name):
    host = mindwm_crd.host_get(kube, host_name)
    return host.wait_until_deleted(timeout=30)


@when("God deletes the MindWM user resource \"{user_name}\"")
def mindwm_user_delete(kube, user_name):
    user = mindwm_crd.user_get(kube,user_name)
    user.delete(None)
@then("the user \"{user_name}\" should be deleted")
def mindwm_user_deleted(kube, user_name):
    user = mindwm_crd.user_get(kube,user_name)
    user.wait_until_deleted()

@when("God deletes the MindWM context resource \"{context_name}\"")
def mindwm_context_delete(kube, context_name):
    ctx = mindwm_crd.context_get(kube, context_name)
    ctx.delete(None)
@then("the context \"{context_name}\" should be deleted")
def mindwm_context_deleted(kube, context_name):
    ctx = mindwm_crd.context_get(kube, context_name)
    ctx.wait_until_deleted(30)

def pytest_collection_modifyitems(config: pytest.Config, items: List[pytest.Item]):
    # XXX workaround
    for item in items:
        item.add_marker(pytest.mark.namespace(create = False, name = "default"))

