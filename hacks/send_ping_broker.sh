HOST=`hostname -s`
CONTEXT_NAME="pink"

export INGRESS_NAME=istio-ingressgateway
export INGRESS_NS=istio-system
export INGRESS_HOST=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

trace_id_gen() {
	local spanid="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)"
}

TRACE_ID="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32)"
SPAN_ID="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)"
TRACEPARENT="00-${TRACE_ID}-${SPAN_ID}-01" 

payload() {
cat<<EOF
{
  "input": "#ping",
  "output": "",
  "ps1": "❯",
  "type": "org.mindwm.v1.iodocument"
}
EOF
} 

#    'http://176.124.198.10/context-'${CONTEXT_NAME}'/context-broker'  \
#    -H "Host: broker-ingress.knative-eventing.svc.cluster.local" \
payload | jq | curl \
    -vvvv \
    -XPOST  \
    "http://${INGRESS_HOST}/context-${CONTEXT_NAME}/context-broker"  \
    -H "Host: broker-ingress.knative-eventing.svc.cluster.local" \
    -H "Content-Type: application/json" \
    -H "traceparent: $TRACEPARENT" \
    -H "Ce-specversion: 1.0" \
    -H "Ce-id: $TRACE_ID" \
    -H "ce-source:org.mindwm."$USER"."$HOST".tmux.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36" \
    -H "ce-subject:#ping" \
    -H "ce-type: org.mindwm.v1.iodocument" \
    -d@-

echo "try to curl $TRACE_ID"
sleep 5
#curl -vvv -H 'Host: tempo.mindwm.local' http://${INGRESS_HOST}/api/traces/${TRACE_ID} | jq #| tee /tmp/answer.json
curl -vvv http://tempo.mindwm.local/api/traces/${TRACE_ID} | jq #| tee /tmp/answer.json
#curl -vvv tempo.stg1.mindwm.local/api/traces/${TRACE_ID} #| jq #| tee /tmp/answer.json
