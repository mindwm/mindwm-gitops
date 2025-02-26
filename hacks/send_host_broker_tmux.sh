export HOST=$(hostname -s);
export CONTEXT_NAME=pink;
echo $HOST

export INGRESS_NAME=istio-ingressgateway
export INGRESS_NS=istio-system
export INGRESS_HOST=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

TRACE_ID="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32)"
SPAN_ID="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)"
TRACEPARENT="00-${TRACE_ID}-${SPAN_ID}-01" 

payload() {
cat<<EOF
{
  "keys": [
    "uptime"
  ]
}
EOF
} 


# tmux send keys
SOURCE="org.mindwm.v1.mindmap-terminal"
SUBJECT="org.mindwm."$USER"."$HOST".tmux.$(echo ${TMUX} | base64).09fb195c-c419-6d62-15e0-51b6ee990922.0.$(echo ${TMUX_PANE} | sed 's/%//')" 
#TYPE="org.mindwm.v1.tmux.send-keys"
TYPE=org.mindwm.v1.ping

payload
#
URI=/user-alice/user-broker

payload | jq | curl \
    -vvvv \
    -XPOST  \
    "http://${INGRESS_HOST}${URI}"  \
    -H "Host: broker-ingress.knative-eventing.svc.cluster.local" \
    -H "Content-Type: application/json" \
    -H "traceparent: $TRACEPARENT" \
    -H "Ce-specversion: 1.0" \
    -H "Ce-id: $TRACE_ID" \
    -H "ce-subject: ${SUBJECT}" \
    -H "ce-source: ${SOURCE}" \
    -H "ce-type: ${TYPE}" \
    -d@-

