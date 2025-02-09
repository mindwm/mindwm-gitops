@mindwm_eda
@mindwm_test
Feature: Mindwm event driven architecture

  Background:
    Given a kubernetes cluster
    Then all nodes in Kubernetes are ready

  Scenario: MindWM CRD
    Given a MindWM environment
    Then following CRD should exists
      | Plural    | Group     | Version |
      | xhosts    | mindwm.io | v1beta1 |
      | xcontexts | mindwm.io | v1beta1 |
      | xusers    | mindwm.io | v1beta1 |

  Scenario: Knative operator
    And namespace "knative-operator" should exist
    And the following deployments are in a ready state in the "knative-operator" namespace
      | Deployment name      |
      | knative-operator     |
      | operator-webhook     |

    Then following CRD should exists
      | Plural            | Group                | Version |
      | knativeeventings  | operator.knative.dev | v1beta1 |
      | knativeservings   | operator.knative.dev | v1beta1 |


  Scenario: Knative Serving
    And namespace "knative-serving" should exist
    And the following deployments are in a ready state in the "knative-serving" namespace
      | Deployment name      | 
      | activator            |
      | autoscaler           |
      | autoscaler-hpa       | 
      | controller           |
      | net-istio-controller |
      | net-istio-webhook    |
      | webhook              |
    And resource "knative-serving" of type "knativeservings.operator.knative.dev/v1beta1" has a status "Ready" equal "True" in "knative-serving" namespace

  Scenario: Knative Eventing
    And namespace "knative-eventing" should exist
    And the following deployments are in a ready state in the "knative-eventing" namespace
      | Deployment name         | 
      | eventing-controller     |
      | eventing-webhook        |
      | imc-dispatcher          |
      | imc-controller          |
      | jetstream-ch-controller |
      | job-sink 		|
      | kafka-controller        |
      | kafka-webhook-eventing  |
      | mt-broker-controller    |
      | mt-broker-filter        |
      | mt-broker-ingress       |
      | nats-webhook            |
    And resource "knative-eventing" of type "knativeeventings.operator.knative.dev/v1beta1" has a status "Ready" equal "True" in "knative-eventing" namespace
   

  Scenario: Istio
    And namespace "istio-system" should exist
    And the following deployments are in a ready state in the "istio-system" namespace
      | Deployment name         | 
      | istiod                  |
      | istio-ingressgateway    |

  Scenario: ArgoCD
    Then the VirtualService "argocd-vs" in the "argocd" namespace should return HTTP status code "200" for the "/" URI

  Scenario: Redpanda
    And namespace "redpanda" should exist
    And the following deployments are in a ready state in the "redpanda" namespace
      | Deployment name         | 
      | redpanda-operator       |
    And helm release "neo4j-cdc" is deployed in "redpanda" namespace
    And statefulset "neo4j-cdc" in namespace "redpanda" is in ready state
    And the following deployments are in a ready state in the "redpanda" namespace
      | Deployment name         | 
      | neo4j-cdc-console       |

  Scenario: Cert manager
    And namespace "cert-manager" should exist
    And the following deployments are in a ready state in the "cert-manager" namespace
      | Deployment name          | 
      | cert-manager             |
      | cert-manager-cainjector |
      | cert-manager-webhook     |

  Scenario: Nats
    And namespace "nats" should exist
    And the following deployments are in a ready state in the "nats" namespace
      | Deployment name         | 
      | nats-box                |
    And statefulset "nats" in namespace "nats" is in ready state

  Scenario: Monitoring
    And namespace "monitoring" should exist
    And the following deployments are in a ready state in the "monitoring" namespace
      | Deployment name         | 
      | loki-gateway | 
      | otel-collector-opentelemetry-collector | 
      | vm-aio-grafana | 
      | vm-aio-kube-state-metrics | 
      | vm-aio-victoria-metrics-operator | 
      | vmagent-vm-aio-victoria-metrics-k8s-stack | 
      | vmalert-vm-aio-victoria-metrics-k8s-stack | 
      | vmsingle-vm-aio-victoria-metrics-k8s-stack | 
    And statefulset "loki" in namespace "monitoring" is in ready state
    And statefulset "tempo" in namespace "monitoring" is in ready state
    And statefulset "vmalertmanager-vm-aio-victoria-metrics-k8s-stack" in namespace "monitoring" is in ready state
    And resource "monitoring-gateway" of type "gateways.networking.istio.io/v1" exists in "monitoring" namespace
    And the following resources of type "virtualservices.networking.istio.io/v1" exists in "monitoring" namespace
      | Istio virtual service name | Host                 | # host not checked
      | grafana-vs                 | grafana.mindwm.local |
      | loki-vs                    | loki.mindwm.local    |
      | tempo-vs                   | tempo.mindwm.local    |
      | vm-vs                      | vm.mindwm.local    |
    And the following VirtualServices in the "monitoring" namespace should return the correct HTTP codes.
      | Istio virtual service name | URL      | Code |  
      | grafana-vs                 | /login   | 200  |
      | loki-vs                    | /        | 200  |
      | tempo-vs                   | /ready   | 200  |
      | vm-vs                      | /ready   | 200  | 

  Scenario: Crossplane
    And namespace "crossplane-system" should exist
    And the following deployments are in a ready state in the "crossplane-system" namespace
      | Deployment name                         |
      | crossplane                              |
      | crossplane-rbac-manager                 |
    And the following cluster resources of type "providers.pkg.crossplane.io/v1" has a status "Healthy" equal "True"
      | Crossplane function |
      | provider-helm       |
      | provider-kubernetes |
    And the following cluster resources of type "functions.pkg.crossplane.io/v1" has a status "Healthy" equal "True"
      | Crossplane function |
      | function-auto-ready |
      | function-kcl        |

  Scenario: Tekton-pipelines
    And namespace "tekton-pipelines" should exist
    And namespace "tekton-pipelines-resolvers" should exist
    And the following deployments are in a ready state in the "tekton-pipelines" namespace
      | Deployment name                         |
      | tekton-events-controller                |
      | tekton-pipelines-controller             |
      | tekton-pipelines-webhook                |
    And the following deployments are in a ready state in the "tekton-pipelines-resolvers" namespace
      | Deployment name                         |
      | tekton-pipelines-remote-resolvers       |

  Scenario: zot registry
    And namespace "zot" should exist
    And the following deployments are in a ready state in the "zot" namespace
      | Deployment name                         |
      | zot                                     |
