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
    name = "neo4j-standalone"
    repoURL = "https://helm.neo4j.com/neo4j"
}

vector : schema.HelmChart = {
    name = "vector"
    repoURL = "https://helm.vector.dev"
}

flux : schema.HelmChart = {
    name = "flux2" 
    repoURL = "https://fluxcd-community.github.io/helm-charts"
}

crossplane : schema.HelmChart = {
    name = "crossplane" 
    repoURL = "https://charts.crossplane.io/stable"
}

kiali_operator : schema.HelmChart = {
    name = "kiali-operator"
    repoURL = "https://kiali.org/helm-charts"
} 

kube_prometheus_stack : schema.HelmChart = {
    name = "kube-prometheus-stack"
    repoURL ="https://prometheus-community.github.io/helm-charts"
} 
