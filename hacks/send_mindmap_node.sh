HOST=`hostname -s`
CONTEXT_NAME="red2"

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
  "title": "testNode",
  "details": "test details",
  "attributes": {
    "a": "b"
  },
  "note": "testNote"
}
EOF
} 

#    'http://176.124.198.10/context-'${CONTEXT_NAME}'/context-broker'  \
#    -H "Host: broker-ingress.knative-eventing.svc.cluster.local" \
payload | jq | curl \
    -vvvv \
    -XPOST  \
    "mindwm-function.default.10.24.142.129.nip.io"  \
    -H "Host: mindwm-function.default.10.24.142.129.nip.io" \
    -H "Content-Type: application/json" \
    -H "traceparent: $TRACEPARENT" \
    -H "Ce-specversion: 1.0" \
    -H "Ce-id: $TRACE_ID" \
    -H "ce-source:org.mindwm."$USER"."$HOST".freeplane.333373" \
    -H "ce-subject:org.mindwm."$USER"."$HOST".freeplane.Map1.node.ID_37777"\
    -H "ce-type: org.mindwm.v1.mindmap.node.update" \
    -d@-

#echo "try to curl $TRACE_ID"
#sleep 5
#curl -vvv http://tempo.mindwm.local/api/traces/${TRACE_ID} | jq #| tee /tmp/answer.json



#curl -vvv -H 'Host: tempo.mindwm.local' http://${INGRESS_HOST}/api/traces/${TRACE_ID} | jq #| tee /tmp/answer.json
#curl -vvv tempo.stg1.mindwm.local/api/traces/${TRACE_ID} #| jq #| tee /tmp/answer.json
