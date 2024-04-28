import .schema as schema
import k8s.api.core.v1 as k8core
import ..nats as nats
import ..helm.chart as charts
import ..argocd.schema as argocdSchema

neo4j_version = "4.4.32"

ContextNamespace = lambda ctx : schema.MindwmContext -> str {
    "context-" + ctx.name
}
UserNamespace = lambda user : schema.MindwmUser -> str {
    "user-" + user.username 
}

omg_user : schema.MindwmUser = {
    username = "omg"    
    hosts = [
        {
            hostname = "snpnd"
        }
    ]
} 

bebebeko_user : schema.MindwmUser = {
    username = "bebebeko" 
    hosts = [
        {
            hostname = "amanda"
        }
    ]
} 

MindWM : [schema.MindwmContext] = [
    {
        name = "team-a" 
        users = [ bebebeko_user, omg_user ]
    }
] 

makeHost = lambda user : schema.MindwmUser, host : schema.MindwmUserHost {
    [
        nats.NatsJetStreamChannel {
            metadata.namespace = UserNamespace(user)
        } 
    ]
}

makeUser = lambda user : schema.MindwmUser {
    [
        k8core.Namespace {
            metadata.name = "user-" + user.username
        } 
    ] + \
    sum([makeHost(user, host) for host in user.hosts], [])
} 

makeContext = lambda context : schema.MindwmContext -> [] {
    [
        k8core.Namespace {
            metadata.name = context.name
        }
        argocdSchema.argoHelmRelease({
            namespace = ContextNamespace(context)
            name = "neo4j"
            chart = charts.neo4j
            version = neo4j_version
        }) 
        
    ] + \
    sum([makeUser(user) for user in context.users], [])
}


make = lambda mindwm : [schema.MindwmContext] -> [] {
    # https://www.kcl-lang.io/docs/user_docs/support/faq-kcl#60-how-to-convert-a-list-of-lists-to-a-single-list-in-kcl
    sum([makeContext(ctx) for ctx in mindwm], [])
}



