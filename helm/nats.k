import ..argocd_app

nats = argocd_app.ArgoCdHelmRelease {
    metadata = {
        name = "nats",
    },
    spec = {
        destination = {
            namespace = "nats"
        }
        source = {
            chart = "nats",
            repoURL = "https://nats-io.github.io/k8s/helm/charts/",
            targetRevision = "1.1.10"
            helm = {
                valuesObject = {
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
                    service = {
                        merge.spec.type = 'NodePort'
                        ports.cluster.enabled = True
                    }


                }
                releaseName = "nats"
            }
        }
        syncPolicy = {
            automated = {},
            syncOptions = ["CreateNamespace=true"]
        }
    }
}

