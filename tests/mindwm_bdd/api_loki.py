import json
import pprint

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
        limit=1000
    )
    assert(res.status_code == 200)
    loki_answer = json.loads(res.content)
    assert (loki_answer['status'] == "success")
    assert (loki_answer['data']['resultType'] == "streams")
    r = {}
    for result in loki_answer['data']['result']:
        pod_name = result['stream']['pod']
        pod_name = result['stream']['app']
        container_name = result['stream']['container']
        if pod_name not in r:
            r[pod_name] = {}
        if container_name not in r[pod_name]:
            r[pod_name][container_name] = ""
        for item in reversed(result['values']):
            log_entry = json.loads(item[1])['log']
            r[pod_name][container_name] += log_entry
    return r
    #return res['data']['result']

#pod_logs = loki_pod_logs_range("context-varanasi", "dead-letter-.*", 240)
#if re.search("cloudevent", pod_logs['dead-letter-00001']["user-container"], re.DOTALL):
#    print("match")

#print(json.dumps(xxx))
#print(json.dumps(json.loads(res), indent=4, default=str))
#print(res.status_code)
#print(json.dumps(json.loads(res.content), indent=4, default=str))
