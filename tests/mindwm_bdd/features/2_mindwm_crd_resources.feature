@mindwm_crd_resources
@mindwm_test
Feature: MindWM Custom kubernetes resources

  Background:
    Given a MindWM environment
    Then all nodes in Kubernetes are ready
    
  Scenario: Create Context and check k8s resources
    When God creates a MindWM context with the name "cyan"
    Then the context should be ready and operable
    And namespace "context-cyan" should exist 
    And helm release "cyan-neo4j" is deployed in "context-cyan" namespace
    And statefulset "cyan-neo4j" in namespace "context-cyan" is in ready state
    And the following knative services are in a ready state in the "context-cyan" namespace
      | Knative service name |
      | dead-letter          |
      | clipboard            |
      | iocontext            |
      | kafka-cdc            |
      | pong                 |
    And the following knative triggers are in a ready state in the "context-cyan" namespace
      | Knative trigger name |
      | iocontext-trigger    |
      | kafka-cdc-trigger    |
      | pong-trigger         |
      | clipboard-trigger    |
    And the following knative brokers are in a ready state in the "context-cyan" namespace
      | Knative broker name |
      | context-broker      |
    And kafka topic "context-cyan-cdc" is in ready state in "redpanda" namespace
    And kafka source "context-cyan-cdc-kafkasource" is in ready state in "context-cyan" namespace
  
  Scenario: Create User and check k8s resources
    When God creates a MindWM user resource with the name "bob" and connects it to the context "cyan"
    Then the user resource should be ready and operable
    And namespace "user-bob" should exist 
    And the following knative brokers are in a ready state in the "user-bob" namespace
      | Knative broker name |
      | user-broker         |
    And the following knative triggers are in a ready state in the "context-cyan" namespace
      | Knative trigger name          |
      | context-cyan-to-user-bob    |
    And the following knative triggers are in a ready state in the "user-bob" namespace
      | Knative trigger name          |
      | user-bob-to-context-cyan    |

  Scenario: Create Host and check k8s resources
    When God creates a MindWM host resource with the name "workstation" and connects it to the user "bob"
    Then the host resource should be ready and operable
    And NatsJetStreamChannel "workstation-host-broker-kne-trigger" is ready in "user-bob" namespace
    And the following knative triggers are in a ready state in the "user-bob" namespace
      | Knative trigger name                    |
      | user-bob-to-context-cyan              |
      | user-broker-to-workstation-broker-trigger    |
    And the following knative brokers are in a ready state in the "user-bob" namespace
      | Knative broker name  |
      | workstation-host-broker   |



  Scenario: Delete Resources and Verify Cleanup

    When God deletes the MindWM host resource "workstation"
    Then the host "workstation" should be deleted

    When God deletes the MindWM user resource "bob"
    Then the user "bob" should be deleted
    And namespace "user-bob" should not exist

    When God deletes the MindWM context resource "cyan"
    Then the context "cyan" should be deleted
    And namespace "context-cyan" should not exist



