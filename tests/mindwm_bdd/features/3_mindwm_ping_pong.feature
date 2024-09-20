@ping_pong
Feature: MindWM Ping-pong EDA test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Ping <context>

    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | pong                 |

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable

    When God starts reading message from NATS topic "user-<username>.<host>-host-broker-kne-trigger._knative"
    When God creates a new cloudevent 
      And sets cloudevent "ce-id" to "<cloudevent_id>"
      And sets cloudevent "traceparent" to "<traceparent>"
      And sets cloudevent "ce-subject" to "#ping"
      And sets cloudevent "ce-source" to "org.mindwm.<username>.<host>.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sets cloudevent "ce-type" to "org.mindwm.v1.iodocument"
      And sends cloudevent to "context-broker" in "context-<context>" namespace
    Then the trace with "<traceparent>" should appear in TraceQL
    And the trace should contains 
      | service name                    | 
      | broker-ingress.knative-eventing | 
      | unknown_service                 | 
      | jetstream-ch-dispatcher         |
    And a cloudevent with type == "org.mindwm.v1.pong" should have been received from the NATS topic

    Examples:
     | context | username   | host      | cloudevent_id                        | traceparent 					         |
     | green4   | amanda4   | pi6-host  | 442af213-c860-4535-b639-355f13b2d443 | 00-5df92f3577b34da6a3ce929d0e0e4734-00f067aa0ba902b7-00 |


   Scenario: Cleanup <username>@<host> in <context>
     When God deletes the MindWM host resource "<host>"
     Then the host "<host>" should be deleted

     When God deletes the MindWM user resource "<username>"

     When God deletes the MindWM context resource "<context>"

     Examples:
     | context | username | host        | 
     | green4   | amanda4   | pi6-host         |

