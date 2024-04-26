import .schema as schema


redpanda_operator : schema.HelmChart = {
    name = "operator"
    repoURL = "https://charts.redpanda.com"
}

cert_manager : schema.HelmChart = {
    name = "cert-manager"
    repoURL = "https://charts.jetstack.io"
}

nats : schema.HelmChart = {
    name = "nats"
    repoURL = "https://nats-io.github.io/k8s/helm/charts/"
}

istio_base : schema.HelmChart = {
    name = "base"
    repoURL = "https://istio-release.storage.googleapis.com/charts"
}


istiod = istio_base | { name = "istiod" }

istio_gateway = istio_base | { name = "gateway" }

neo4j : schema.HelmChart = {
    name = "neo4j"
    repoURL = "https://helm.neo4j.com/neo4j"
}
