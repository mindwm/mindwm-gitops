import allure
import json
import logging

from kubetest import condition
from kubetest import utils as kubetest_utils

from grafana_loki_client import Client
from grafana_loki_client.api.query_range import get_loki_api_v1_query_range
from datetime import datetime, timedelta
import re

logger = logging.getLogger(__name__)
logging.getLogger('httpx').setLevel(logging.ERROR)
logging.getLogger('httpcore').setLevel(logging.ERROR)

def loki_pod_logs_range(namespace, pod_name_regex, duration_min):
    loki_client = Client("http://loki.mindwm.local:80")
    query = '{namespace="' + namespace + '", pod=~"' + pod_name_regex + '"} |= ``'
    end_time = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    start_time = (datetime.utcnow() - timedelta(minutes=duration_min)).strftime('%Y-%m-%dT%H:%M:%SZ')

    res = get_loki_api_v1_query_range.sync_detailed(
        client=loki_client, 
        query=query, 
        start=start_time, 
        end=end_time, 
        limit=4096 #lines
    )
    assert(res.status_code == 200)
    loki_answer = json.loads(res.content)
    assert (loki_answer['status'] == "success")
    assert (loki_answer['data']['resultType'] == "streams")
    r = {}
    for result in loki_answer['data']['result']:
        pod_name = result['stream']['pod']
        container_name = result['stream']['container']
        if pod_name not in r:
            r[pod_name] = {}
        if container_name not in r[pod_name]:
            r[pod_name][container_name] = ""
        for item in reversed(result['values']):
            log_entry = json.loads(item[1])['log']
            r[pod_name][container_name] += log_entry
    return r

def loki_logs_contain_regex(namespace, pod_name_regex, container_name, match_regex):
    duration_min = 10
    loki_logs = loki_pod_logs_range(namespace, pod_name_regex, duration_min)
    for pod_name in loki_logs:
        if re.search(pod_name_regex, pod_name):
            assert(container_name in loki_logs[pod_name])
            if re.search(match_regex, loki_logs[pod_name][container_name], re.DOTALL):
                return True

    assert(False)

#def _pod_logs_contain_regex(should_contain, namespace, pod_name_regex, container_name, log_regex):
def _pod_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex):
    def log_match_regex():
        try:
            r = loki_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex)
            return r != None
        except Exception as e:
            return False

    condition_name = f"{pod_name_regex} pod, container {container_name} should contain {log_regex}"

    with allure.step(condition_name):
        kubetest_utils.wait_for_condition(
            condition=condition.Condition(condition_name, log_match_regex),
            timeout=30,
            interval=3
        )

def pod_logs_should_contain_regex(namespace, pod_name_regex, container_name, log_regex):
    _pod_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex)

def pod_logs_should_not_contain_regex(namespace, pod_name_regex, container_name, log_regex):
    try:
        _pod_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex)
        loki_logs = loki_pod_logs_range(namespace, pod_name_regex, 10)
                        
    except TimeoutError as e:
        pass
        return True

    for pod_name in loki_logs:
        if re.search(pod_name_regex, pod_name):
            assert(container_name in loki_logs[pod_name])
            if re.search(log_regex, loki_logs[pod_name][container_name], re.DOTALL):
                allure.attach(loki_logs[pod_name][container_name], name = f"{pod_name}/{container_name} logs", attachment_type='text/plain')

    raise TimeoutError


#And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback (most recent call last):" regex
# namespace = "context-red"
# pod_name_regex = "^.*-00001-deployment-.*"
# container_name = "user-container"
# log_regex = "Traceback \(most recent call last\):"
# r = pod_logs_should_contain_regex(namespace, pod_name_regex, container_name, log_regex)
# pprint.pprint(r)
