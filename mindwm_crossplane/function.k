import .schema as CrossPlaneSchema


kcl : CrossPlaneSchema.CrossPlaneFunction = {
    name = "function-kcl"
    package = "xpkg.upbound.io/crossplane-contrib/function-kcl:v0.16.2"
}

auto_ready : CrossPlaneSchema.CrossPlaneFunction = {
    name = "function-auto-ready"
    package = "xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.4.1"
} 

makeCrossPlaneFunction = lambda cross_func : CrossPlaneSchema.CrossPlaneFunction {
    {  
        apiVersion = "pkg.crossplane.io/v1beta1"
        kind = "Function"
        spec = {
            package = cross_func.package
        } 
        metadata = {
            name = cross_func.name
            annotations = {
                "argocd.argoproj.io/sync-options" = "SkipDryRunOnMissingResource=true"
            }
        }
    }
}     
