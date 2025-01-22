import json
import pprint

from kubetest import condition
from kubetest import utils as kubetest_utils

from grafana_loki_client import Client
from grafana_loki_client.api.query_range import get_loki_api_v1_query_range
from datetime import datetime, timedelta
import re


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
        #pod_name = result['stream']['app']
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
            #print(f"find {match_regex} in {pod_name}/{container_name}")
            assert(container_name in loki_logs[pod_name])
            #pprint.pprint(loki_logs[pod_name][container_name])
            if re.search(match_regex, loki_logs[pod_name][container_name], re.DOTALL):
                #print(f"found {match_regex} in {pod_name}/{container_name}")
                return True

    assert(False)

#def _pod_logs_contain_regex(should_contain, namespace, pod_name_regex, container_name, log_regex):
def _pod_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex):
    def log_match_regex():
        try:
            r = loki_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex)
            return r != None
        except Exception as e:
            #pprint.pprint(e)
            return False

    kubetest_utils.wait_for_condition(
        condition=condition.Condition(f"{pod_name_regex} pod, container {container_name} should contain {log_regex}", log_match_regex),
        timeout=30,
        interval=3
    )

def pod_logs_should_contain_regex(namespace, pod_name_regex, container_name, log_regex):
    _pod_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex)

def pod_logs_should_not_contain_regex(namespace, pod_name_regex, container_name, log_regex):
    try:
        _pod_logs_contain_regex(namespace, pod_name_regex, container_name, log_regex)
    except TimeoutError as e:
        pass
        return
    raise TimeoutError


# namespace = "context-red"
# pod_name_regex = "dead-letter-.*"
# container_name = "user-container"
# log_regex = "cloudevents.Event\n"
# r = pod_logs_should_contain_regex(namespace, pod_name_regex, container_name,"cloudevents.Event\n")
# pprint.pprint(r)
