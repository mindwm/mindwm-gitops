import .schema as CrossPlaneSchema
import json_merge_patch as p
import k8s.api.core.v1 as k8core
import k8s.api.rbac.v1 as k8rbac
import ..config as config


kubernetes : CrossPlaneSchema.CrossPlaneProvider = {
    name = "provider-kubernetes"
    package = "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.18.0"
} 


helm : CrossPlaneSchema.CrossPlaneProvider = {
    name = "provider-helm"
    package = "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.20.4"
} 

http : CrossPlaneSchema.CrossPlaneProvider = {
    name = "provider-http"
    package = "xpkg.upbound.io/crossplane-contrib/provider-http:v1.0.8"
}

makeCrossPlaneProvider = lambda cross_provider : CrossPlaneSchema.CrossPlaneProvider {
    {  
        apiVersion = "pkg.crossplane.io/v1"
        kind = "Provider"
        spec = {
            package = cross_provider.package
        } 
        metadata = {
            name = cross_provider.name
            annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
            }
        }
    }
}     


makeCrossPlaneProviderMerge = lambda cross_provider : CrossPlaneSchema.CrossPlaneProvider, patch : any {
    p.merge(makeCrossPlaneProvider(cross_provider), patch)
} 

serviceAccountProviderHelm = "provider-helm"

makeCrossPlaneProviderHelm = lambda cross_provider : CrossPlaneSchema.CrossPlaneProvider { 
    [
        makeCrossPlaneProviderMerge(cross_provider, { 
            spec.runtimeConfigRef = { 
                apiVersion = "pkg.crossplane.io/v1beta1"
                kind = "DeploymentRuntimeConfig"
                name = "provider-helm"
            } 
        })
        {
            apiVersion = "pkg.crossplane.io/v1beta1"
            kind = "DeploymentRuntimeConfig"
            metadata.name = "provider-helm"
            spec.serviceAccountTemplate.metadata.name =  serviceAccountProviderHelm
            metadata.annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
            }
        }
        k8rbac.ClusterRoleBinding {
            metadata.name = "provider-helm-cluster-admin"
            subjects = [
                {
                    kind = "ServiceAccount"
                    name = serviceAccountProviderHelm
                    namespace = config.config.crossplane.namespace
                }
            ]
            roleRef = {
                kind = "ClusterRole"
                name = "cluster-admin"
                apiGroup = "rbac.authorization.k8s.io"
            }

        } 

    ]
} 
