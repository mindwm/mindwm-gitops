import argoproj.v1alpha1 as argoproj
import ..helm.schema as helmSchema
import yaml
import file

schema argoHelmRelease[release: helmSchema.HelmRelease](argoproj.Application):
    metadata = {
        name = release.name
        namespace = "argocd"
    }
    spec = {
        destination = {
            namespace = release.namespace
            server = "https://kubernetes.default.svc"
        }
        project = "default"
        source = {
            chart = release.chart.name
            repoURL = release.chart.repoURL
            targetRevision = release.version
            helm = {
                values = yaml.encode(release.values)
                releaseName = release.name
            }


        }
        syncPolicy = {
            automated = {
                selfHeal = True
            }
            syncOptions = [
                "CreateNamespace=true"
            ]
        }

    }

#ArgoCdConfigMap = yaml.decode(file.read("argocd/argoRepoConfigMap.yml"))
ArgoCdConfigMap = yaml.decode(file.read("argocd/argoRepoConfigMap.yml"))
