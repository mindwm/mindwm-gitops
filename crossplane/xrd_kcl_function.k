import manifests
import yaml
import k8s.api.core.v1 as k8core
import template

api_version = "apiextensions.crossplane.io/v1"

composite_version = "v1beta1"


mkComposition = lambda claim_ref : any, schemaSpec : any, steps :[any] {
    group = claim_ref.apiVersion.split("/")[0]
    [
        { 
            apiVersion = api_version
            kind = "CompositeResourceDefinition"
            metadata.name = "x" + claim_ref.kind + "s." + group
            spec = {
                group = group
                names = {
                    kind = "X" + claim_ref.kind.capitalize()
                    plural = "x" + claim_ref.kind + "s"
                } 
                claimNames = {
                    kind = claim_ref.kind.capitalize()
                    plural = claim_ref.kind + "s"
                }
                # TODO(@metacoma) currently support only one version
                versions = [
                    {
                        name = composite_version
                        referenceable = True
                        served = True
                        # TODO(@metacoma) currently support only one type of object schema with only one property name (string)
                        schema.openAPIV3Schema = { 
                            type = "object"
                            properties.spec = schemaSpec 
                        } 

                    }
                ] 

            } 
        }
        {
            apiVersion = api_version
            kind = "Composition"
            metadata.name = claim_ref.kind
            spec = {
                compositeTypeRef = {
                    apiVersion = claim_ref.apiVersion
                    kind = "X" + claim_ref.kind.capitalize()
                }
                mode = "Pipeline"
                pipeline = steps + [
                    {    
                        step = "automatically-detect-ready-composed-resources"
                        functionRef.name = "function-auto-ready" # required installed function function-auto-ready
                    }
                ] 
            } 
        }
    ]
} 

# oh :(
makeVarName = lambda var : str -> str {
    "$" + "{" + var + "}"
} 

makeContextXR = lambda {
    mkComposition({ 
        apiVersion = "mindwm.io/" + composite_version
        kind = "context"
    }, {
        type = "object"
        properties.name.type = "string"
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLRun"
                spec.source = template.execute("""context_name = option("params").oxr.spec.name
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = "context-configmap-{{ context_name }}"
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "v1"
          kind = "ConfigMap"
          metadata.name = "context-configmap-{{ context_name }}"
          metadata.namespace = "default"
          data = {
            foo = "bar"
          }
        }
      }
    }
  }
]
""", {
    context_name = makeVarName("context_name")
}) 
            } 
        }
    ])
} 

makeUserXR = lambda {
    mkComposition({ 
        apiVersion = "mindwm.io/" + composite_version
        kind = "user"
    }, {
        type = "object"
        properties.name.type = "string"
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLRun"
                spec.source = template.execute("""user_name = option("params").oxr.spec.name
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = "user-configmap-{{ user_name }}"
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "v1"
          kind = "ConfigMap"
          metadata.name = "user-configmap-{{ user_name }}"
          metadata.namespace = "default"
          data = {
            foo = "bar"
          }
        }
      }
    }
  }
]
""", {
    user_name = makeVarName("user_name")
}) 
            } 
        }
    ])
} 

makeHostXR = lambda {
    mkComposition({ 
        apiVersion = "mindwm.io/" + composite_version
        kind = "host"
    }, {
        type = "object"
        properties.name.type = "string"
    }, [
        {
            step = "resources"
            functionRef.name = "function-kcl"
            input = {
                apiVersion = "krm.kcl.dev/v1alpha1"
                kind = "KCLRun"
                spec.source = template.execute("""host_name = option("params").oxr.spec.name
items = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata.name = "host-configmap-{{ host_name }}"
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "v1"
          kind = "ConfigMap"
          metadata.name = "host-configmap-{{ host_name }}"
          metadata.namespace = "default"
          data = {
            foo = "bar"
          }
        }
      }
    }
  }
]
""", {
    host_name = makeVarName("host_name")
}) 
            } 
        }
    ])
} 

manifests.yaml_stream([
    makeContextXR()
    makeUserXR()
    makeHostXR()
])
