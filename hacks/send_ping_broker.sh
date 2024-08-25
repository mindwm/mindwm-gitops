HOST=`hostname`

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
    -vvv \
    -XPOST  \
    http://broker-ingress.knative-eventing.svc.cluster.local/context-pink/context-broker  \
    -H "Content-Type: application/json" \
    -H "Ce-specversion: 1.0" \
    -H "Ce-id: XXX" \
    -H "ce-source:org.mindwm.'$USER'.'$HOST'.tmux.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36" \
    -H "ce-subject:#ping" \
    -H "ce-type: org.mindwm.v1.iodocument" \
    -d@-
'

