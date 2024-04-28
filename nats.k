config = {
    cluster.merge.name = "nats-cluster"
    jetstream.enable = True
    merge.accounts = {
        "$SYS.users" = {
	        user = "sys"
	        password = "pass"
        }
        root = {
            jetstream = "enable"
            user = "sys"
            password = "pass"
        }
    }
}


NatsJetStreamChannel =  {
    apiVersion = "messaging.knative.dev/v1alpha1"
    kind = "NatsJetStreamChannel"
    metadata = {
        name = "mindwm"
        namespace = "knative-eventing"
    }
 
}
