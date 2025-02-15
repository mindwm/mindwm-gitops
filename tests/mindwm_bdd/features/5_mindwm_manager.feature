@mindwm_manager
@mindwm_test
Feature: MindWM manager integration test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

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
     | tratata | ci         | localhost | 

  Scenario: Mindwm-manager integration test
    When God clones the repository '<manager_repo>' with branch '<manager_branch>' and commit '<manager_commit>' to '<work_dir>'
    Then the directory '<work_dir>' should exist
    When God runs the command 'python3.11 -m venv .venv' inside the '<work_dir>' directory
    When God runs the command '.venv/bin/pip install -r requirements.txt' inside the '<work_dir>' directory
    When God creates a tmux session named '<tmux_session>' with a window named '<tmux_window_name>'
    Then the tmux session '<tmux_session>' should exist
    When God saves pane content of "0" in "<tmux_session>", window "<tmux_window_name>" to "/tmp/pane_0"
    Then God sends the command 'cd <work_dir>' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command '. .venv/bin/activate' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'export HOST=<host>' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'export NATS_URL=nats://root:r00tpass@nats.mindwm.local:4222' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'export MINDWM_EVENT_SUBJECT_PREFIX="org.mindwm.<user>.<host>"' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'export MINDWM_FEEDBACK_SUBJECT="user-<user>.<host>-host-broker-kne-trigger._knative"' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'export MINDWM_SURREALDB_URL="ws://127.0.0.1:8000/mindwm/context_graph"' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'export MINDWM_SURREALDB_ENABLED="False"' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God sends the command 'python3.11 src/manager.py' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '0'
    Then God waits for '5' seconds
    Then file "/tmp/pane_0" should not contain "Traceback \(most recent call last\):" regex
    Then God vertically splits the tmux session '<tmux_session>', window '<tmux_window_name>'
    When God saves pane content of "1" in "<tmux_session>", window "<tmux_window_name>" to "/tmp/pane_1"
    Then God sends the command 'cd <work_dir> && bash ./join.sh' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '1'
    Then God waits for '5' seconds
    Then God sends the command 'id' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '1'
    Then God sends the command 'echo integration-test' to the tmux session '<tmux_session>', window '<tmux_window_name>', pane '1'
    Examples:
     | manager_repo                             | manager_branch | manager_commit | work_dir            | host      | user | tmux_session | tmux_window_name |
     | https://github.com/mindwm/mindwm-manager | master         | HEAD           | /tmp/mindwm-manager | localhost | ci   | test-integration | main |

  Scenario: Verification that the io-document has been delivered and processed
    Then the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name            |
      | iocontext-00001-deployment |
    And container "user-container" in pod "iocontext-00001-deployment.*" in namespace "context-<context>" should contain "integration-test" regex
    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "context-<context>" should not contain "Traceback \(most recent call last\):" regex
    And container "user-container" in pod "^dead-letter-.*" in namespace "context-<context>" should not contain "cloudevents.Event\n" regex
    Then file "/tmp/pane_0" should not contain "Traceback \(most recent call last\):" regex
    Then file "/tmp/pane_0" contain "integration-test" regex

    Examples:
      | context | username   | host      |
      | tratata | ci         | localhost |

  Scenario: Cleanup <username>@<host> in <context>
    # TODO(@metacoma) cleanup tmux session
    When God deletes the MindWM host resource "<host>"
    When God deletes the MindWM user resource "<username>"
    When God deletes the MindWM context resource "<context>"

    Examples:
    | context | username | host      |
    | tratata | ci       | localhost |
