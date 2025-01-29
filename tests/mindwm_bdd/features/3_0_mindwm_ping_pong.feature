@mindwm_ping_pong
@mindwm_test
Feature: MindWM Ping-pong EDA test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Prepare environment for ping tests 
    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    And resource "pong" of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable
    And resource "<host>-host-broker-kne-trigger" of type "natsjetstreamchannels.messaging.knative.dev/v1alpha1" has a status "Ready" equal "True" in "user-<username>" namespace

    When God starts reading message from NATS topic ">"

    Examples:
     | context | username   | host      |
     | green4   | amanda4   | pi6-host  | 

  Scenario: Send ping to knative ping service, context: <context>, username: <username>, host: <host>
    When God creates a new cloudevent 
      And sets cloudevent header "ce-subject" to "#ping"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sends cloudevent to knative service "pong" in "context-<context>" namespace
      """
      {
        "input": "#ping",
        "output": "",
        "ps1": "❯",
        "type": "org.mindwm.v1.iodocument"
      } 
      """
      Then the response http code should be "200"

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name       |
      | pong-00001-deployment |

    Examples:
     | context | username   | host      |
     | green4   | amanda4   | pi6-host  | 

  Scenario: Send ping cloudevent to endpoint <endpoint>, username: <username>, host: <host>, traceparent: <traceparent>
    When God creates a new cloudevent 
      And sets cloudevent header "ce-subject" to "#ping"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "traceparent" to "<traceparent>"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sends cloudevent to "<endpoint>"
      """
      {
        "input": "#ping",
        "output": "",
        "ps1": "❯",
        "type": "org.mindwm.v1.iodocument"
      } 
      """
    Then the response http code should be "202"

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name            |
      | pong-00001-deployment |
    Then the trace with "<traceparent>" should appear in TraceQL
    And the trace should contains 
      | service name                    | 
      | broker-ingress.knative-eventing | 
      | unknown_service                 | 
      | jetstream-ch-dispatcher         |
    And a cloudevent with type == "org.mindwm.v1.pong" should have been received from the NATS topic "user-<username>.<host>-host-broker-kne-trigger._knative"

    Examples:
     | context | username   | host      | endpoint | traceparent 					         |
     | green4   | amanda4   | pi6-host  | broker-ingress.knative-eventing/context-green4/context-broker   | 00-5df92f3577b34da6a3ce929d0e0e4734-00f067aa0ba902b7-00 |
     | green4   | amanda4   | pi6-host  | broker-ingress.knative-eventing/user-amanda4/user-broker | 00-6df93f3577b34da6a3ce929d0e0e4742-00f067aa0ba902b7-00 |


  Scenario: Send ping via nats topic "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window><tmux_pane>.iodocument"
    When God creates a new cloudevent 
      And sets cloudevent header "ce-subject" to "#ping"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window>.<tmux_pane>.iodocument"
      And sends cloudevent to nats topic "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window><tmux_pane>.iodocument"
      """
      {
        "input": "#ping",
        "output": "",
        "ps1": "❯",
        "type": "org.mindwm.v1.iodocument"
      } 
      """

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name       |
      | pong-00001-deployment |

    And a cloudevent with type == "org.mindwm.v1.pong" should have been received from the NATS topic "user-<username>.<host>-host-broker-kne-trigger._knative"
    And container "user-container" in pod "^pong-00001-deployment-.*" in namespace "context-<context>" should contain ".*'org.mindwm.v1.pong'*" regex
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex


    Examples:
     | context | username   | host      | tmux_pane | tmux_window | uuid                                  | tmux_socket                     |
     | green4   | amanda4   | pi6-host  | 23        | 36          | 09fb195c-c419-6d62-15e0-51b6ee990922  |L3RtcC90bXV4LTEwMDAvZGVmYXVsdA== |


   Scenario: Cleanup <username>@<host> in <context>
     When God deletes the MindWM host resource "<host>"
     Then the host "<host>" should be deleted
     When God deletes the MindWM user resource "<username>"
     When God deletes the MindWM context resource "<context>"

     Examples:
     | context | username | host        | 
     | green4   | amanda4   | pi6-host         |

