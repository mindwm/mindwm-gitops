[package]
name = "mindwm-gitops"
version = "0.1.0"

[dependencies]
argo-cd-order = { oci = "oci://ghcr.io/kcl-lang/argo-cd-order", tag = "0.2.1" }
argoproj = { oci = "oci://ghcr.io/kcl-lang/argoproj", tag = "0.1.0" }
crossplane = { oci = "oci://ghcr.io/kcl-lang/crossplane", tag = "1.17.3" }
istio = { oci = "oci://ghcr.io/kcl-lang/istio", tag = "1.21.5" }
json_merge_patch = { oci = "oci://ghcr.io/kcl-lang/json_merge_patch", tag = "0.1.1" }
k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.31.2", version = "1.31.2" }
knative = { oci = "oci://ghcr.io/kcl-lang/knative", tag = "0.2.0" }
knative-operator = { oci = "oci://ghcr.io/kcl-lang/knative-operator", tag = "0.3.0" }

[profile]
entries = ["main.k"]
