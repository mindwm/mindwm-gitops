@mindwm_two_hosts_one_user
@mindwm_test
Feature: MindWM two hosts one user function test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Prepare environment, context: <context>, username: <username>
    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable
    And the following resources of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace
      | Knative service name |
      | dead-letter          |
      | clipboard            |
      | iocontext            |
      | kafka-cdc            |
      | pong                 |
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    Examples:
    | context  | username |
    | varanasi | shesha   |

  Scenario: Create <host> for user <username>

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable

    Examples:
    | username | host           |
    | shesha   | workstation01  |
    | shesha   | travellaptop   |


  Scenario: Send ping via nats host: <host>, user: <username>
    When God creates a new cloudevent 
      And God starts reading message from NATS topic ">"
      And sets cloudevent header "ce-subject" to "#ping"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window>.<tmux_pane>.iodocument"
      And sends cloudevent to nats topic "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window>.<tmux_pane>.iodocument"
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
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex

    Examples:
     | context | username   | host      | tmux_pane | tmux_window | uuid                                  | tmux_socket                     |
     | varanasi  | shesha   | workstation01  | 23        | 36          | 8d839f82-79da-11ef-bc9f-f74fac7543ac  |L3RtcC90bXV4LTEwMDAvZGVmYXVsdA== |
     | varanasi  | shesha   | travellaptop  | 23        | 36          | 8d839f82-79da-11ef-bc9f-f74fac7543ac  |L3RtcC90bXV4LTEwMDAvZGVmYXVsdA== |

  Scenario: Send iodocument via nats host: <host>, user: <username> and check that second host received graph the update
    When God creates a new cloudevent 
      And sets cloudevent header "ce-subject" to "id"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "ce-source" to "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window>.<tmux_pane>.iodocument"
      And sends cloudevent to nats topic "org.mindwm.<username>.<host>.<tmux_socket>.<uuid>.<tmux_window><tmux_pane>.iodocument"
      """
      {
        "input": "id",
        "output": "uid=1000(pion) gid=1000(pion) groups=1000(pion),4(adm),100(users),112(tmux),988(docker)",
        "ps1": "pion@mindwm-stg1:~/work/dev/mindwm-manager$",
        "type": "org.mindwm.v1.iodocument"
      } 
      """

    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name       |
      | iocontext-00001-deployment |
      | kafka-cdc-00001-deployment |

    And a cloudevent with type == "org.mindwm.v1.graph.created" should have been received from the NATS topic "user-<username>.travellaptop-host-broker-kne-trigger._knative"
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex

    Examples:
     | context | username   | host      | tmux_pane | tmux_window | uuid                                  | tmux_socket                     |
     | varanasi  | shesha   | workstation01  | 23        | 36          | 8d839f82-79da-11ef-bc9f-f74fac7543ac  |L3RtcC90bXV4LTEwMDAvZGVmYXVsdA== |
     #| varanasi  | shesha   | travellaptop  | 23        | 36          | 8d839f82-79da-11ef-bc9f-f74fac7543ac  |L3RtcC90bXV4LTEwMDAvZGVmYXVsdA== |


  Scenario: Cleanup hosts <host> in user <username>
    When God deletes the MindWM host resource "<host>"
    Then the host "<host>" should be deleted

    Examples:
    | username | host           |
    | shesha   | workstation01  |
    | shesha   | travellaptop   |

  Scenario: Cleanup user <username> and context <context>
    When God deletes the MindWM user resource "<username>"
    Then the user "<username>" should be deleted
    When God deletes the MindWM context resource "<context>"
    Then the context "<context>" should be deleted

    Examples:
    | context  | username |
    | varanasi | shesha   |
