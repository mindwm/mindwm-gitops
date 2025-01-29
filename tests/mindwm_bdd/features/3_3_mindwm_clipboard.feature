@mindwm_clipboard
@mindwm_test
Feature: MindWM clipboard EDA test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Prepare environment, context: <context>, username: <username>, host: <host>
    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    And resource "clipboard" of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable
    And resource "<host>-host-broker-kne-trigger" of type "natsjetstreamchannels.messaging.knative.dev/v1alpha1" has a status "Ready" equal "True" in "user-<username>" namespace

    When God starts reading message from NATS topic ">"

    Examples:
     | context | username   | host      |
     | philadelphia   | flukeman   | the-host  | 

  Scenario: Send clipboard cloudevent to knative ping service 
    When God creates a new cloudevent 
      And sets cloudevent header "ce-subject" to "clipboard"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.clipboard"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.clipboard"
      And sets cloudevent header "traceparent" to "<traceparent>"
      And sends cloudevent to knative service "clipboard" in "context-<context>" namespace
      """
      {
        "uuid": "6ca8a133-aba6-4f7f-ab95-242802fcac2c",
        "time": 1728325473,
        "data": "clipboard primary data"
      } 
      """
      Then the response http code should be "200"

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name       |
      | clipboard-00001-deployment |
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex

    Examples:
     | context | username   | host      | traceparent                                             |
     | philadelphia   | flukeman   | the-host  | 00-6ef92f3577b34da6a3ce929d0e0e4734-00f067aa0ba902b7-00 |

  Scenario: Send ping directly to function <endpoint>
    When God creates a new cloudevent 
      And God starts reading message from NATS topic ">"
      And sets cloudevent header "ce-subject" to "clipboard"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.clipboard"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.clipboard"
      And sets cloudevent header "traceparent" to "<traceparent>"
      And sends cloudevent to "<endpoint>"
      """
      {
        "uuid": "4bca8a133-aba6-4f7f-ab95-242802fcac2c",
        "time": 1728325474,
        "data": "clipboard secondary data"
      } 
      """
    Then the response http code should be "202"

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name            |
      | clipboard-00001-deployment |
    Then the trace with "<traceparent>" should appear in TraceQL
    And the trace should contains 
      | service name                    | 
      | broker-ingress.knative-eventing | 
      | unknown_service                 | 
      | jetstream-ch-dispatcher         |
    And a cloudevent with type == "org.mindwm.v1.graph.created" should have been received from the NATS topic "user-<username>.<host>-host-broker-kne-trigger._knative"
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex

    Examples:
     | context | username   | host      | endpoint | traceparent 					         |
     | philadelphia   | flukeman   | the-host  | broker-ingress.knative-eventing/context-philadelphia/context-broker   | 00-5df92f3577b34da6a3ce929d0e0e4734-00f067aa0ba902b7-00 |
     | philadelphia   | flukeman   | the-host  | broker-ingress.knative-eventing/user-flukeman/user-broker | 00-6df93f3577b34da6a3ce929d0e0e4742-00f067aa0ba902b7-00 |


  Scenario: Send ping via nats topic "org.mindwm.<username>.<host>.clipboard"
    When God creates a new cloudevent 
      And sets cloudevent header "ce-id" to "<uuid>"
      And sets cloudevent header "ce-subject" to "clipboard"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.clipboard"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.clipboard"
      And sets cloudevent header "traceparent" to "<traceparent>"
      And sends cloudevent to nats topic "org.mindwm.<username>.<host>.clipboard"
      """
      {
        "uuid": "3bca8a133-aba6-4f7f-ab95-242802fcac3c",
        "time": 1728325474,
        "data": "clipboard #3 data"
      } 
      """

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name       |
      | clipboard-00001-deployment |

    And a cloudevent with type == "org.mindwm.v1.graph.created" should have been received from the NATS topic "user-<username>.<host>-host-broker-kne-trigger._knative"
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex


    Examples:
     | context | username   | host      | uuid                                  | traceparent |
     | philadelphia   | flukeman   | the-host  | 09fb195c-c419-6d62-15e0-51b6ee990922 | 00-8af92f3577b34da6a3ce929d0e0e4742-00f067aa0ba902b7-00 |


  Scenario: Cleanup <username>@<host> in <context>
    When God deletes the MindWM host resource "<host>"
    Then the host "<host>" should be deleted

    When God deletes the MindWM user resource "<username>"

    When God deletes the MindWM context resource "<context>"

    Examples:
    | context | username | host        | 
    | philadelphia   | flukeman   | the-host         |

