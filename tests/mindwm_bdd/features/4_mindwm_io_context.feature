@io_context
Feature: MindWM io context function test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: io context <context>

    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | iocontext            |
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable

    When God creates a new cloudevent 
      And sets cloudevent "ce-id" to "<cloudevent_id>"
      And sets cloudevent "traceparent" to "<traceparent>"
      And sets cloudevent "ce-subject" to "id"
      And sets cloudevent "ce-source" to "org.mindwm.<username>.<host>.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sets cloudevent "ce-type" to "org.mindwm.v1.iodocument"
    When sends cloudevent to "context-broker" in "context-<context>" namespace
        """
        {	
          "input": "id",
          "output": "uid=1000(pion) gid=1000(pion) groups=1000(pion),4(adm),100(users),112(tmux),988(docker)",
          "ps1": "pion@mindwm-stg1:~/work/dev/mindwm-manager$"
        }
        """
    Then following deployments is in ready state in "context-<context>" namespace
      | Deployment name            |
      | iocontext-00001-deployment |
    Then the trace with "<traceparent>" should appear in TraceQL
    And the trace should contains
      | service name                    |
      | broker-ingress.knative-eventing |
      | unknown_service                 |
    Then neo4j have node "User" with property "username" = "<username>"
    And neo4j have node "Host" with property "hostname" = "<host>"
    And neo4j have node "IoDocument" with property "input" = "id"

    Examples:
     | context | username   | host      | cloudevent_id                        | traceparent 					         |
     | red   | kitty   | tablet  | 442af213-c860-4535-b639-355f13b2d883 | 00-7df92f3577b34da6a3ce930d0e0e4734-00f064aa0ba902b8-00 |


  Scenario: Cleanup <username>@<host> in <context>
    When God deletes the MindWM host resource "<host>"
    Then the host "<host>" should be deleted

    When God deletes the MindWM user resource "<username>"

    When God deletes the MindWM context resource "<context>"

    Examples:
    | context | username | host        | 
    | red   | kitty   | tablet         |

