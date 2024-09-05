HOST=`hostname -s`
CONTEXT_NAME="cyan"

trace_id_gen() {
	local spanid="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)"
}

TRACE_ID="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 32)"
SPAN_ID="$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)"
TRACEPARENT="00-${TRACE_ID}-${SPAN_ID}-01" 

payload() {
cat<<EOF
{
  "uuid": "0b604285-d136-404e-8a2f-168f6a235b44",
  "input": "#ping",
  "output": "",
  "ps1": "❯",
  "type": "org.mindwm.v1.iodocument"
}
EOF
} 

kexec() {
	kubectl run kexec-$$ --rm -i --image=nicolaka/netshoot --restart=Never -- sh -c "$*" 
} 

payload | jq | kexec 'curl \
    -vvvv \
    -XPOST  \
    http://broker-ingress.knative-eventing.svc.cluster.local/context-'${CONTEXT_NAME}'/context-broker  \
    -H "Content-Type: application/json" \
    -H "traceparent:'$TRACEPARENT'" \
    -H "Ce-specversion: 1.0" \
    -H "Ce-id: XXX" \
    -H "ce-source:org.mindwm.'$USER'.'$HOST'.tmux.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36" \
    -H "ce-subject:#ping" \
    -H "ce-type: org.mindwm.v1.iodocument" \
    -d@-
'

echo "try to curl TRACE_ID"
sleep 20
#curl -G -s http://tempo.stg1.mindwm.local/api/traces/${TRACE_ID} | jq | tee /tmp/answer.json
