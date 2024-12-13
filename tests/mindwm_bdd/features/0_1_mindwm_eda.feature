@eda
Feature: Mindwm event driven architecture
  Background:
    Given a MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Knative
    And namespace "knative-serving" should exist
    And namespace "knative-eventing" should exist
    And namespace "knative-operator" should exist
    And the following deployments are in a ready state in the "knative-serving" namespace
      | Deployment name      | 
      | activator            |
      | autoscaler           |
      | autoscaler-hpa       | 
      | controller           |
      | net-istio-controller |
      | net-istio-webhook    |
      | webhook              |
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
   

  Scenario: Istio
    And namespace "istio-system" should exist
    And the following deployments are in a ready state in the "istio-system" namespace
      | Deployment name         | 
      | istiod                  |
      | istio-ingressgateway    |

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

  Scenario: Gitea
    And namespace "gitea" should exist
