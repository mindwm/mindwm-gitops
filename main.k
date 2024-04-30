import argo_cd_order as ArgoCdOrder
import .argocd.schema as argocdSchema
import .helm.chart as charts
import yaml
import manifests
import k8s.api.core.v1 as k8core
import file
import .istio as istio
import .nats as nats
import knative_operator.v1beta1 as knative
import knative as knativeConfig
import json_merge_patch as p
import .mindwm.context as mindwm_context
import .flux as flux
#import argoproj.v1alpha1 as argoproj


argoCdOrder = ArgoCdOrder.make({
    Sync =  [
        k8core.Namespace {
            metadata.name = "redpanda"
        } 
        argocdSchema.argoHelmRelease({
            namespace = "cert-manager"
            name = "cert-manager"
            chart = charts.cert_manager
            version = "1.14.4"
            values = {
                installCRDs = True
            }
        })

        # required by redpanda-operator
        # https://docs.redpanda.com/current/deploy/deployment-option/self-hosted/kubernetes/k-deployment-overview/
        argocdSchema.argoHelmRelease({
            namespace = flux.namespace
            name = "flux"
            chart = charts.flux
            version = flux.chart_version
        })
        ] + yaml.decode_all(file.read("redpanda/crds.yaml")) \
        + yaml.decode_all(file.read("redpanda/fix_cluster_role_binding.yaml")) \
        + [
        argocdSchema.argoHelmRelease({
            namespace = "redpanda"
            name = "redpanda-operator"
            chart = charts.redpanda_operator
            version = "0.4.21"
        })
        yaml.decode_all(file.read("redpanda/cluster.yaml"))
        yaml.decode_all(file.read("redpanda/topic.yaml"))
    ] 


})

manifests.yaml_stream([
    #yaml.decode_all(file.read("manifests/knative-operator.yaml"))
    argoCdOrder
])


