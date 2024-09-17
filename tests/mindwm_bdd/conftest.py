import pytest
import re
import pprint
import kubetest
from kubetest.client import TestClient
from kubernetes import client
from pytest_bdd import scenarios, scenario, given, when, then, parsers
import mindwm_crd
import re
import os
import utils
from typing import List
from make import run_make_cmd

@pytest.fixture 
def ctx():
    return {}

@scenario('kubernetes.feature','Validate Mindwm custom resource definitions')
def test_scenario():
    assert False


@given(".*kubernetes cluster$")
def kubernetes_cluster(kube, clusterinfo):
    assert(clusterinfo.cluster), f"{clusterinfo} "

@then("all nodes in kubernetes are ready")
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
    context = mindwm_crd.context_get(kube, context_name)
    context.delete(None)
@then("the context \"{context_name}\" should be deleted")
def mindwm_context_deleted(kube, context_name):
    context= mindwm_crd.context_get(kube, context_name)
    context.wait_until_deleted(30)

@given("an Ubuntu {ubuntu_version} system with {cpu:d} CPUs and {mem:d} GB of RAM")
def environment(ctx, kube, ubuntu_version, cpu, mem):
    print("XXX")
    ctx['cpu'] = cpu
    ctx['mem'] = mem
    ctx['ubuntu_version'] = ubuntu_version
    assert(cpu >= 6), f"Cpu < 6"
    assert(mem >= 16), f"Mem < 16"
    assert(ubuntu_version == "22.04" or ubuntu_version == "24.04")
    pass

@given("the mindwm-gitops repository is cloned into the \"{repo_dir}\" directory")
def mindwm_repo(ctx, kube, repo_dir):
    ctx['repo_dir'] =  os.path.expanduser(repo_dir)
    assert(os.path.isdir(ctx['repo_dir'])), f"No such directory {ctx['repo_dir']}"
    pass

@when("God executes \"make {target_name}\"")
def run_make(ctx, kube, target_name):
    run_make_cmd(f"make {target_name}", ctx['repo_dir'])
    #run_make_cmd(f"make {target_name}", "xx")

@then("helm release {helm_release} is deployed in {namespace} namespace" )
def helm_release_deploeyd(kube, helm_release, namespace):
    info = utils.helm_release_info(kube, helm_release, namespace)
    assert(info['status'] == "deployed")
    pass


def pytest_collection_modifyitems(config: pytest.Config, items: List[pytest.Item]):
    # XXX workaround
    for item in items:
        item.add_marker(pytest.mark.namespace(create = False, name = "default"))

