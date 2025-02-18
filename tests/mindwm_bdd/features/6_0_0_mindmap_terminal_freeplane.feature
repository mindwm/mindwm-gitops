@mindmap_terminal
@mindwm_test

Feature: Mindmap terminal integration test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Install freeplane
    When God runs the command 'wget -c -O /tmp/freeplane.deb https://sourceforge.net/projects/freeplane/files/freeplane%20stable/freeplane_1.12.9~upstream-1_all.deb/download' inside the '<work_dir>' directory
    When God runs the command 'sudo dpkg -i <work_dir>/freeplane.deb' inside the '<work_dir>' directory
    Examples: 
      | work_dir               | display |
      | /tmp/                  | 42      |


  Scenario: Prepare environment, context: <context>, username: <username>, host: <host>
    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable

    And the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name               |
      | iocontext-00001-deployment    |

    And the following resources of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace
      | Knative service name |
      | iocontext            |

    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable

    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable

    Examples:
     | context | username   | host      |
     | headwind | ci  | localhost | 

  Scenario: Clone <repo>@<branch> to <clone_dir>
    When God clones the repository '<repo>' with branch '<branch>' and commit '<commit>' to '<clone_dir>'
    Then the directory '<clone_dir>' should exist

    Examples:
      | repo                                        | branch | commit | clone_dir             |
      | https://github.com/mindwm/mindmap-terminal  | master | HEAD   | /tmp/mindmap-terminal |
      | https://github.com/mindwm/mindwm-manager    | master | HEAD   | /tmp/mindwm-manager   |

  Scenario: Install, configure and run mindwm-manager
    Then the directory '<work_dir>' should exist
    When God runs the command 'python3.11 -m venv .venv' inside the '<work_dir>' directory
    When God runs the command '.venv/bin/pip install -r requirements.txt' inside the '<work_dir>' directory
    When God runs the command 'set -a && . <work_dir>/.env.sample && /<work_dir>/.venv/bin/python3.11 src/manager.py > <work_dir>/log 2>&1 &' inside the '<work_dir>' directory
    Then God waits for '5' seconds
    When God runs the command 'pgrep -fx "^//tmp/mindwm-manager/.venv/bin/python3.11 src/manager.py$"' inside the '<work_dir>' directory
    Then file "<work_dir>/log" should not contain "Traceback \(most recent call last\):" regex
    Then file "<work_dir>/log" contain "INFO:mindwm.events:Subscribed to NATS subject:.*" regex

    Examples:
      | work_dir            |
      | /tmp/mindwm-manager | 
  #
  Scenario: Run xvfb server at :<display> port
    When God runs the command 'nohup Xvfb :<display> -screen 0 1024x768x16 > /tmp/x 2>&1 &' inside the '<work_dir>' directory
    When God runs the command 'nohup fvwm3 -d :<display> >/tmp/y 2>&1 &' inside the '<work_dir>' directory
    When God runs the command 'pgrep -f ^Xvfb' inside the '<work_dir>' directory
    When God runs the command 'pgrep -f ^fvwm3' inside the '<work_dir>' directory

    Examples: 
      | display | work_dir |
      | 42      | /tmp     |
  #
  Scenario: Run freeplane
    When God runs the command 'export DISPLAY=:<display>; make freeplane_start > <work_dir>/log 2>&1 &' inside the '<work_dir>' directory
    Then God waits for '10' seconds
    When God runs the command 'DISPLAY=:<display> wmctrl -l | grep Freeplane' inside the '<work_dir>' directory
    When God runs the command 'DISPLAY=:<display> wmctrl -l | grep -E "mindmap-terminal-[0-9]+-Map[0-9]+?-ID_[0-9]+"' inside the '<work_dir>' directory

    Examples: 
      | work_dir               | display |
      | /tmp/mindmap-terminal  | 42      |

  Scenario: Run test
    When God runs the command 'export DISPLAY=:<display>; xdotool search --name "freeplane" windowactivate' inside the '<work_dir>' directory
    Then God waits for '3' seconds
    When God runs the command 'export DISPLAY=:<display>; xdotool key Escape' inside the '<work_dir>' directory
    Then God waits for '3' seconds
    When God runs the command 'export DISPLAY=:<display>; xdotool type "uptime"' inside the '<work_dir>' directory
    Then God waits for '3' seconds
    When God runs the command 'export DISPLAY=:<display>; xdotool key Return' inside the '<work_dir>' directory
    Examples: 
      | work_dir               | display |
      | /tmp/mindmap-terminal  | 42      |
  #
  #
  Scenario: Verification that the io-document has been delivered and processed
    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name            |
      | iocontext-00001-deployment |
    And container "user-container" in pod "iocontext-00001-deployment.*" in namespace "context-<context>" should contain "uptime" regex
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex

    Examples:
      | context | username   | host      |
      | headwind | ci         | localhost |

  Scenario: Cleanup <username>@<host> in <context>
    # TODO(@metacoma) cleanup tmux session
    When God deletes the MindWM host resource "<host>"
    When God deletes the MindWM user resource "<username>"
    When God deletes the MindWM context resource "<context>"

    Examples:
    | context | username | host      |
    | headwind | ci       | localhost |
