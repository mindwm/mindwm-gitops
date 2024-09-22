@kafka_cdc
Feature: MindWM kafka_cdc function test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: io context <context>

    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | kafka-cdc            |
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable

    When God starts reading message from NATS topic "user-<username>.<host>-host-broker-kne-trigger._knative"

    And God creates graph user node in context "<context>"
    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | kafka-cdc            |
    And a cloudevent with type == "org.mindwm.v1.graph.created" should have been received from the NATS topic

    When God updates graph user node in context "<context>"
    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | kafka-cdc            |
    And a cloudevent with type == "org.mindwm.v1.graph.updated" should have been received from the NATS topic


    When God deletes graph user node in context "<context>"
    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | kafka-cdc            |
    And a cloudevent with type == "org.mindwm.v1.graph.deleted" should have been received from the NATS topic

    Examples:
     | context  | username   | host      | 
     | blue     | garmr      | helheim   | 


  Scenario: Cleanup <username>@<host> in <context>
    When God deletes the MindWM host resource "<host>"
    Then the host "<host>" should be deleted

    When God deletes the MindWM user resource "<username>"

    When God deletes the MindWM context resource "<context>"

    Examples:
    | context | username | host      | 
    | blue    | garmr    | helheim   | 

