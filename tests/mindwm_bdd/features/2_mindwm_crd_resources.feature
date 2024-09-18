@crd_resources
Feature: MindWM Custom kubernetes resources

  Background:
    Given a MindWM environment
    
  Scenario: Create Context and check k8s resources
    When God creates a MindWM context with the name "pink"
    Then the context should be ready and operable
    And namespace "context-pink" should exists 
    And helm release "pink-neo4j" is deployed in "context-pink" namespace
    And statefulset "pink-neo4j" in namespace "context-pink" is in ready state
    And following knative service is in ready state in "context-pink" namespace
      | Knative service name |
      | dead-letter          |
      | iocontext            |
      | kafka-cdc            |
      | pong                 |
    And following knative triggers is in ready state in "context-pink" namespace
      | Knative trigger name |
      | iocontext-trigger    |
      | kafka-cdc-trigger    |
      | pong-trigger         |
    And following knative brokers is in ready state in "context-pink" namespace
      | Knative broker name |
      | context-broker      |
    And kafka topic "context-pink-cdc" is in ready state in "redpanda" namespace
    And kafka source "context-pink-cdc-kafkasource" is in ready state in "context-pink" namespace
  
  Scenario: Create User and check k8s resources
    When God creates a MindWM user resource with the name "alice" and connects it to the context "pink"
    Then the user resource should be ready and operable
    And namespace "user-alice" should exists 
    And following knative brokers is in ready state in "user-alice" namespace
      | Knative broker name |
      | user-broker         |
    And following knative triggers is in ready state in "context-pink" namespace
      | Knative trigger name          |
      | context-pink-to-user-alice    |
    And following knative triggers is in ready state in "user-alice" namespace
      | Knative trigger name          |
      | user-alice-to-context-pink    |

  Scenario: Create Host and check k8s resources
    When God creates a MindWM host resource with the name "laptop" and connects it to the user "alice"
    Then the host resource should be ready and operable
    And NatsJetStreamChannel "laptop-host-broker-kne-trigger" is ready in "user-alice" namespace
    And following knative triggers is in ready state in "user-alice" namespace
      | Knative trigger name                    |
      | user-alice-to-context-pink              |
      | user-broker-to-laptop-broker-trigger    |
    And following knative brokers is in ready state in "user-alice" namespace
      | Knative broker name  |
      | laptop-host-broker   |



  Scenario: Delete Resources and Verify Cleanup
    When God deletes the MindWM context resource "pink"
    Then the context "pink" should be deleted
    And namespace "context-pink" should not exists

    When God deletes the MindWM host resource "laptop"
    Then the host "laptop" should be deleted

    When God deletes the MindWM user resource "alice"
    Then the user "alice" should be deleted
    And namespace "user-alice" should not exists

