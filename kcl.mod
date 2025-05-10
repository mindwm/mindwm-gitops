[package]
name = "mindwm-gitops"
version = "0.1.0"

[dependencies]
argoproj = { oci = "oci://ghcr.io/kcl-lang/argoproj", tag = "0.1.0" }
crossplane = "1.16.0"
istio = "1.21.2"
json_merge_patch = { oci = "oci://ghcr.io/kcl-lang/json_merge_patch", tag = "0.1.0" }
k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.31.2", version = "1.31.2" }
knative = { oci = "oci://ghcr.io/kcl-lang/knative", tag = "0.2.0" }
knative-operator = { oci = "oci://ghcr.io/kcl-lang/knative-operator", tag = "0.3.0" }

[profile]
entries = ["main.k"]
