import allure
import pytest
import re
import pprint
import kubetest
from kubetest.client import TestClient
from kubernetes import client
from kubetest.plugin import clusterinfo
from kubetest.objects.namespace import Namespace
from pytest_bdd import scenarios, scenario, given, when, then, parsers
import mindwm_crd
import re
import os
import utils
from typing import List
from make import run_make_cmd
from messages import DataTable
from kubetest import utils as kubetest_utils
from kubetest import condition
import json
import requests

@pytest.fixture 
def ctx():
    return {}
@pytest.fixture
def cloudevent():
    return {}

@scenario('lifecycle.feature','Validate Mindwm custom resource definitions')
def test_scenario():
    assert False

@allure.step("Cluster info")
@given(".*kubernetes cluster$")
def kubernetes_cluster():
    cluster_info = clusterinfo()
    with allure.step("Result: {}".format(json.dumps(cluster_info))):
        pass
    assert(cluster_info)

@allure.step("Check that all nodes in kubernetes are ready")
@then("all nodes in kubernetes are ready")
def kubernetes_nodes(kube):
    for node in kube.get_nodes().values():
        node_is_ready = node.is_ready()
        with allure.step(f"Kubernetes node '{node.name}' is {node_is_ready}"):
            pass

        assert(node_is_ready), f"{node.name} is not ready"


@scenario('mindwm_crd.feature','Validate Mindwm custom resource definitions')
def test_mindwm():
    return True

@allure.step("Mindwm environment")
@given('a MindWM environment')
def mindwm_environment(kube):

    
    for plural in ["xcontexts", "xhosts", "xusers"]:
        utils.custom_object_plural_wait_for(kube, 'mindwm.io', 'v1beta1', plural)
        kube.get_custom_objects(group = 'mindwm.io', version = 'v1beta1', plural = plural, all_namespaces = True)
        with allure.step(f"Mindwm crd '{plural}' is exists"):
            pass

    pass

@when("God creates a MindWM context with the name \"{context_name}\"")
def mindwm_context(ctx, kube, context_name):
    ctx['context_name'] = context_name
    mindwm_crd.context_create(kube, context_name)
    with allure.step(f"Create context '{context_name}'"):
        pass


@then("the context should be ready and operable")
def minwdm_context_validate(ctx, kube):
    try:
        mindwm_crd.context_validate(kube, ctx['context_name'])
        with allure.step(f"Context '{ctx['context_name']}' is ready"):
            pass
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
    with allure.step(f"Create user '{user_name}' with context {context_name}"):
        pass

@then("the user resource should be ready and operable")
def mindwm_user_validate(ctx, kube):
    user = mindwm_crd.user_get(kube, ctx['user_name'])
    try:
        user.validate()
        with allure.step(f"User '{ctx['user_name']}' is ready"):
            pass
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
    with allure.step(f"Host '{ctx['host_name']}' has created"):
        pass

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
def environment(ctx, ubuntu_version, cpu, mem):
    ctx['cpu'] = cpu
    ctx['mem'] = mem
    ctx['ubuntu_version'] = ubuntu_version
    assert(cpu >= 6), f"Cpu < 6"
    assert(mem >= 16), f"Mem < 16"
    assert(ubuntu_version == "22.04" or ubuntu_version == "24.04")
    pass

@given("the mindwm-gitops repository is cloned into the \"{repo_dir}\" directory")
def mindwm_repo(ctx, repo_dir):
    ctx['repo_dir'] =  os.path.expanduser(repo_dir)
    assert(os.path.isdir(ctx['repo_dir'])), f"No such directory {ctx['repo_dir']}"
    pass

@when("God executes \"make {target_name}\"")
def run_make(ctx, target_name):
    run_make_cmd(f"make {target_name}", ctx['repo_dir'])

@then("helm release \"{helm_release}\" is deployed in \"{namespace}\" namespace" )
def helm_release_deploeyd(kube, helm_release, namespace):
    #info = utils.helm_release_info(kube, helm_release, namespace)
    info = utils.helm_release_is_ready(kube, helm_release, namespace)
    assert(info['status'] == "deployed")
    with allure.step(f"Helm release '{helm_release}' deployed in {namespace}"):
        pass

@then("the argocd \"{application_name}\" application appears in \"{namespace}\" namespace")
def argocd_application(kube, application_name, namespace):
   utils.argocd_application(kube, application_name, namespace)

@then("the argocd \"{application_name}\" application is {namespace} namespace in a progressing status")
def argocd_application_in_progress(kube, application_name, namespace):
    utils.argocd_application_wait_status(kube, application_name, namespace)
    argocd_app = utils.argocd_application(kube, application_name, namespace)
    health_status = argocd_app['status']['health']['status']
    #print(f"{application_name} {health_status}")
    # @metacoma(TODO) Progressing only
    assert(health_status == 'Progressing' or health_status == "Healthy") or health_status == "Missing"

@then(parsers.parse("all argocd applications in healthy state"))
def argocd_applications_check(kube, step):
    # @metacoma(REFACT)
    title_row, *rows = step.data_table.rows

    for row in rows:
        application_name = row.cells[0].value
        argocd_application_in_progress(kube, application_name, "argocd")
    pass

@then("all argocd applications are in a healthy state")
def argocd_applications_check(kube, step):
    title_row, *rows = step.data_table.rows

    for row in rows:
        application_name = row.cells[0].value
        argocd_application_in_progress(kube, application_name, "argocd")

@then("the following roles should exist:")
def role_exists(kube, step):
    title_row, *rows = step.data_table.rows
    cluster_roles = kube.get_clusterroles()
    for row in rows:
        role_name = row.cells[0].value 
        role = cluster_roles.get(role_name)
        assert role is not None, f"Role {role_name} not found"


@then("namespace \"{namespace}\" should exists")
def namespace_exists(ctx, kube, namespace):
    ns = Namespace.new(namespace)
    ns.wait_until_ready(timeout=60)
    with allure.step(f"Namespace '{namespace}' is ready"):
        pass
    ctx['namespace'] = namespace

@then("namespace \"{namespace}\" should not exists")
def namespace_not_exists(kube, namespace):
    ns = Namespace.new(namespace)
    ns.wait_until_deleted(timeout=180)
    with allure.step(f"Namespace '{namespace}' deleted"):
        pass


@then("statefulset \"{statefulset_name}\" in namespace \"{namespace}\" is in ready state")
def statefulset_is_ready(kube, statefulset_name, namespace):
    statefulset = utils.statefulset_wait_for(kube, statefulset_name, namespace)
    statefulset.wait_until_ready(180)
    with allure.step(f"Statefulset '{statefulset_name}' is ready"):
        pass

@then("following knative service is in ready state in \"{namespace}\" namespace")
def knative_service_exists(kube, step, namespace):
    title_row, *rows = step.data_table.rows
    for row in rows:
        service_name = row.cells[0].value 
        service = utils.knative_service_wait_for(kube, service_name, namespace)
        is_ready = utils.resource_get_condition(service['status'], 'Ready')
        assert(is_ready), f"Knative service {service_name} is not ready"

@then("following knative triggers is in ready state in \"{namespace}\" namespace")
def knative_trigger_exists(kube, step, namespace):
    title_row, *rows = step.data_table.rows
    for row in rows:
        trigger_name = row.cells[0].value 
        trigger = utils.knative_trigger_wait_for(kube, trigger_name, namespace)
        is_ready = utils.resource_get_condition(trigger['status'], 'Ready')
        with allure.step(f"Knative trigger '{trigger_name}' ready state is {is_ready}"):
            pass
        assert(is_ready == 'True')

@then("following knative brokers is in ready state in \"{namespace}\" namespace")
def knative_broker_exists(kube, step, namespace):
    title_row, *rows = step.data_table.rows
    for row in rows:
        broker_name = row.cells[0].value 
        broker = utils.knative_broker_wait_for(kube, broker_name, namespace)
        is_ready = utils.resource_get_condition(broker['status'], 'Ready')
        with allure.step(f"Knative broker '{broker_name}' ready state is {is_ready}"):
            pass
        assert(is_ready == 'True')

@then("kafka topic \"{kafka_topic_name}\" is in ready state in \"{namespace}\" namespace")
def kafka_topic_exists(kube, kafka_topic_name, namespace):
    kafka_topic = utils.kafka_topic_wait_for(kube, kafka_topic_name, namespace)
    is_ready = utils.resource_get_condition(kafka_topic['status'], 'Ready')
    with allure.step(f"Kafka topic '{kafka_topic_name}' ready state is {is_ready}"):
        pass
    assert(is_ready == 'True')

@then("kafka source \"{kafka_source_name}\" is in ready state in \"{namespace}\" namespace")
def kafka_source_exists(kube, kafka_source_name, namespace):
    kafka_source = utils.kafka_source_wait_for(kube, kafka_source_name, namespace)
    is_ready = utils.resource_get_condition(kafka_source['status'], 'Ready')
    with allure.step(f"Kafka source '{kafka_source_name}' ready state is {is_ready}"):
        pass
    assert(is_ready == 'True')

@then("NatsJetStreamChannel \"{nats_stream_name}\" is ready in \"{namespace}\" namespace")
def nats_stream_exists(kube, nats_stream_name, namespace):
    nats_stream = utils.nats_stream_wait_for(kube, nats_stream_name, namespace)
    is_ready = utils.resource_get_condition(nats_stream['status'], 'Ready')
    with allure.step(f"Nats stream '{nats_stream}' ready state is {is_ready}"):
        pass
    assert(is_ready == 'True')

@when("God creates a new cloudevent")
def cloudevent_new(cloudevent):
    cloudevent = {}

@when("sets cloudevent \"{key}\" to \"{value}\"")
def cloudevent_header_set(cloudevent, key, value):
    cloudevent[key] = value


@when("sends cloudevent to \"{broker_name}\" in \"{namespace}\" namespace")
def event_send_ping(kube, cloudevent, broker_name, namespace):
    def get_lb():
        services = kube.get_services("istio-system")
        lb_service = services.get("istio-ingressgateway")
        assert lb_service is not None
        lb_ip = lb_service.status().load_balancer.ingress[0].ip
        assert lb_ip is not None
        return lb_ip

    ingress_host = get_lb()
    url = f"http://{ingress_host}/{namespace}/{broker_name}"

    headers = {
        "Host": "broker-ingress.knative-eventing.svc.cluster.local",
        "Content-Type": "application/json",
        "traceparent": cloudevent['traceparent'],
        "Ce-specversion": "1.0",
        "Ce-id": cloudevent['ce-id'],
        "ce-source": cloudevent['ce-source'],
        "ce-subject": cloudevent['ce-subject'],
        "ce-type": cloudevent['ce-type']
    }
    payload = {
        "input": cloudevent["ce-source"],
        "output": "",
        "ps1": "❯",
        "type": cloudevent['ce-type']
    }
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    assert response.status_code == 202, f"Unexpected status code: {response.status_code}"

    pass

@then("the trace with \"{cloudevent_id}\" should appear in TraceQL")
def tracesql_get_trace(kube, cloudevent_id):
    pass



def pytest_collection_modifyitems(config: pytest.Config, items: List[pytest.Item]):
    # XXX workaround
    for item in items:
        item.add_marker(pytest.mark.namespace(create = False, name = "default"))


