import .schema as schema
import k8s.api.core.v1 as k8core
import ..nats as nats

userNamespace = lambda user : schema.MindwmUser -> str {
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
            metadata.namespace = userNamespace(user)
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
    ] + \
    sum([makeUser(user) for user in context.users], [])
}


make = lambda mindwm : [schema.MindwmContext] -> [] {
    # https://www.kcl-lang.io/docs/user_docs/support/faq-kcl#60-how-to-convert-a-list-of-lists-to-a-single-list-in-kcl
    sum([makeContext(ctx) for ctx in mindwm], [])
}



