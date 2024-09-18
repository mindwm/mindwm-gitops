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


  Scenario: Delete Resources and Verify Cleanup
    When God deletes the MindWM context resource "pink"
    Then the context "pink" should be deleted
    And namespace "context-pink" should not exists
