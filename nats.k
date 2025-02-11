nats_user = "root"
nats_password = "r00tpass"
nats_release_name = "nats"
nats_namespace = "nats"
nats_port = 4222


NatsJetStreamChannel =  {
    apiVersion = "messaging.knative.dev/v1alpha1"
    kind = "NatsJetStreamChannel"
    metadata = {
        name = "mindwm"
        namespace = "knative-eventing"
    }

}
