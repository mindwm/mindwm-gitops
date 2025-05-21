@mindwm_lifecycle
@mindwm_test
Feature: Mindwm Lifecycle Management

  Background:
    Given an Ubuntu 24.04 system with 6 CPUs and 16 GB of RAM
    And the mindwm-gitops repository is cloned into the "~/mindwm-gitops" directory

  Scenario: Deploy Mindwm Cluster and Applications
    When God executes "make cluster"
    Then all nodes in Kubernetes are ready

    When God executes "make argocd"
    Then helm release "argocd" is deployed in "argocd" namespace

    When God executes "make argocd_app"
    Then the argocd "mindwm-gitops" application appears in "argocd" namespace

    When God executes "make argocd_app_sync_async"
    Then the argocd "mindwm-gitops" application is argocd namespace in a progressing status

    When God executes "make argocd_app_async_wait"
    Then all argocd applications are in a healthy state
      | ArgoCD Application name      |
      | cert-manager		     |
      | crossplane		     |
      | istio-base		     |
      | istio-ingressgateway	     |
      | istiod			     |
      | loki			     |
      | mindwm-gitops		     |
      | nats			     |
      | otel-collector		     |
      | promtail		     |
      | redpanda-operator	     |
      | tempo			     |
      | vm-aio			     |
      | redpanda-operator            |

    When God executes "make crossplane_rolebinding_workaround"
    Then the following roles should exist:
      | Role name                      |
      | crossplane-admin               |
    When God executes "make edit_hosts"
    Then file "/etc/hosts" contain "mindwm.local" regex

    When God executes "make forward_dns_cluster_local"
    Then domain name "<registry_domain>" should exist
    Examples:
    | registry_domain               |
    | zot-int.zot.svc.cluster.local |
