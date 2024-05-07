import .schema as CrossPlaneSchema


kcl : CrossPlaneSchema.CrossPlaneFunction = {
    name = "function-kcl"
    package = "xpkg.upbound.io/crossplane-contrib/function-kcl:latest"
}

auto_ready : CrossPlaneSchema.CrossPlaneFunction = {
    name = "function-auto-ready"
    package = "xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.0.0-20231101225931-60aea09d94c8"
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
