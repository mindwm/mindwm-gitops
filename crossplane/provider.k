import .schema as CrossPlaneSchema

kubernetes : CrossPlaneSchema.CrossPlaneProvider = {
    name = "provider-kubernetes"
    package = "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.13.0"
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
