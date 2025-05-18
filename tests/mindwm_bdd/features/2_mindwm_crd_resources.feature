@mindwm_crd_resources
@mindwm_test
Feature: MindWM Custom kubernetes resources

  Background:
    Given a MindWM environment
    Then all nodes in Kubernetes are ready
    
  Scenario: Prepare environment, context: cyan
    When God creates a MindWM context with the name "cyan"
    Then the context should be ready and operable
    And namespace "context-cyan" should exist 
    And helm release "cyan-neo4j" is deployed in "context-cyan" namespace
    And helm release "cyan-node-red" is deployed in "context-cyan" namespace
    And statefulset "cyan-neo4j" in namespace "context-cyan" is in ready state
    Then the following deployments are in a ready state in the "context-cyan" namespace
      | Deployment name |
      | cyan-node-red        |
    And the following resources of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
      | Knative service name |
      | dead-letter          |
      | clipboard            |
      | iocontext            |
      | kafka-cdc            |
      | pong                 |
    And the following resources of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
      | Knative trigger name |
      | iocontext-trigger    |
      | kafka-cdc-trigger    |
      | pong-trigger         |
      | clipboard-trigger    |
    And resource "context-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
    And resource "context-cyan-cdc" of type "topics.cluster.redpanda.com/v1alpha2" has a status "Ready" equal "True" in "redpanda" namespace
    And resource "context-cyan-cdc-kafkasource" of type "kafkasources.sources.knative.dev/v1beta1" has a status "Ready" equal "True" in "context-cyan" namespace
    And resource "gateway" of type "gateways.networking.istio.io/v1" exists in "context-cyan" namespace
    Then the VirtualService "neo4j-virtual-service" in the "context-cyan" namespace should return HTTP status code "200" for the "/" URI
    Then the VirtualService "node-red" in the "context-cyan" namespace should return HTTP status code "200" for the "/" URI

  Scenario: Create User bob
    When God creates a MindWM user resource with the name "bob" and connects it to the context "cyan"
    Then the user resource should be ready and operable
    And namespace "user-bob" should exist 
    And resource "user-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace


    And resource "context-cyan-to-user-bob" of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
    And resource "user-bob-to-context-cyan" of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace

  Scenario: Create Host workstation
    When God creates a MindWM host resource with the name "workstation" and connects it to the user "bob"
    Then the host resource should be ready and operable
    And resource "workstation-host-broker-kne-trigger" of type "natsjetstreamchannels.messaging.knative.dev/v1alpha1" has a status "Ready" equal "True" in "user-bob" namespace
    And the following resources of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace
      | Knative trigger name                    |
      | user-bob-to-context-cyan              |
      | user-broker-to-workstation-broker-trigger    |
    And resource "workstation-host-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace

  Scenario: Delete Resources and Verify Cleanup

    When God deletes the MindWM host resource "workstation"
    Then the host "workstation" should be deleted

    When God deletes the MindWM user resource "bob"
    Then the user "bob" should be deleted
    And namespace "user-bob" should not exist

    When God deletes the MindWM context resource "cyan"
    Then the context "cyan" should be deleted
    And namespace "context-cyan" should not exist
