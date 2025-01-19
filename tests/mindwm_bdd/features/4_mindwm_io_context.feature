@mindwm_io_context
@mindwm_test
Feature: MindWM io context function test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: io context <context>

    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    Then the following knative services are in a ready state in the "context-<context>" namespace
      | Knative service name |
      | iocontext            |
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable
    # When God makes graph query in context "<context>"
    #   """
    #   MATCH (N) DETACH DELETE N;
    #   """

    When God creates a new cloudevent 
      And sets cloudevent header "ce-id" to "<cloudevent_id>"
      And sets cloudevent header "traceparent" to "<traceparent>"
      And sets cloudevent header "ce-subject" to "id"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sends cloudevent to "broker-ingress.knative-eventing/context-<context>/context-broker"
        """
        {	
          "input": "id",
          "output": "uid=1000(pion) gid=1000(pion) groups=1000(pion),4(adm),100(users),112(tmux),988(docker)",
          "ps1": "pion@mindwm-stg1:~/work/dev/mindwm-manager$",
          "type": "org.mindwm.v1.iodocument"
        }
        """
    Then the response http code should be "202"
    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name            |
      | iocontext-00001-deployment |
    # Then the trace with "<traceparent>" should appear in TraceQL
    # And the trace should contains
    #   | service name                    |
    #   | broker-ingress.knative-eventing |
    #   | unknown_service                 |
    Then graph have node "User" with property "username" = "<username>" in context "<context>"
    And graph have node "Host" with property "hostname" = "<host>" in context "<context>"
    And graph have node "IoDocument" with property "input" = "id" in context "<context>"

    Examples:
     | context | username   | host      | cloudevent_id                        | traceparent 					         |
     | red     | kitty      | tablet    | 442af213-c860-4535-b639-355f13b2d883 | 00-7df92f3577b34da6a3ce930d0e0e4734-00f064aa0ba902b8-00 |


  Scenario: Cleanup <username>@<host> in <context>
    When God deletes the MindWM host resource "<host>"
    Then the host "<host>" should be deleted

    When God deletes the MindWM user resource "<username>"

    When God deletes the MindWM context resource "<context>"

    Examples:
    | context | username | host        | 
    | red     | kitty    | tablet      |

