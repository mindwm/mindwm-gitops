@mindwm_crd_resources
@mindwm_test
Feature: MindWM Custom kubernetes resources

  Background:
    Given a MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Prepare environment, context: cyan
    When God creates a MindWM context with the name "cyan"
    Then the context should be ready and operable
    And namespace "context-cyan" should exist
    And helm release "cyan-neo4j" is deployed in "context-cyan" namespace
    And helm release "cyan-node-red" is deployed in "context-cyan" namespace
    And statefulset "cyan-neo4j" in namespace "context-cyan" is in ready state
    Then the following deployments are in a ready state in the "context-cyan" namespace
      | Deployment name |
      | cyan-node-red        |
    And the following resources of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
      | Knative service name |
      | dead-letter          |
      | clipboard            |
      | iocontext            |
      | kafka-cdc            |
      | pong                 |
    And the following resources of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
      | Knative trigger name |
      | iocontext-trigger    |
      | kafka-cdc-trigger    |
      | pong-trigger         |
      | clipboard-trigger    |
    And resource "context-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
    And resource "context-cyan-cdc" of type "topics.cluster.redpanda.com/v1alpha2" has a status "Ready" equal "True" in "redpanda" namespace
    And resource "context-cyan-cdc-kafkasource" of type "kafkasources.sources.knative.dev/v1beta1" has a status "Ready" equal "True" in "context-cyan" namespace
    And resource "gateway" of type "gateways.networking.istio.io/v1" exists in "context-cyan" namespace
    And the following VirtualServices in the "context-cyan" namespace should return the correct HTTP codes.
      | VirtualService             | URI      | Code |
      | neo4j-virtual-service      | /        | 200  |
      | node-red                   | /        | 200  |

  Scenario: Create User bob
    When God creates a MindWM user resource with the name "bob" and connects it to the context "cyan"
    Then the user resource should be ready and operable
    And namespace "user-bob" should exist
    And resource "user-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace
    And resource "context-cyan-to-user-bob" of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-cyan" namespace
    And resource "user-bob-to-context-cyan" of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace

  Scenario: Create Host workstation
    When God creates a MindWM host resource with the name "workstation" and connects it to the user "bob"
    Then the host resource should be ready and operable
    And resource "workstation-host-broker-kne-trigger" of type "natsjetstreamchannels.messaging.knative.dev/v1alpha1" has a status "Ready" equal "True" in "user-bob" namespace
    And the following resources of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace
      | Knative trigger name                    |
      | user-bob-to-context-cyan              |
      | user-broker-to-workstation-broker-trigger    |
    And resource "workstation-host-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "user-bob" namespace

  Scenario: Create mindwm python function magika
    When God creates "<function_name>" resource of type "functions.mindwm.io/v1beta1" in the "<namespace>" namespace
      """
      apiVersion: mindwm.io/v1beta1
      kind: Function
      metadata:
        name: yyy
        namespace: context-cyan
      spec:
        data:
            func.py: |
              from magika import Magika
              m = Magika()
              output = data.get('output')
              res = m.identify_bytes(output.encode('utf-8'))
              print(f"Magika result: ${res.output.label}")
              return CloudEvent(attributes, data)
            requirements.txt: |
              magika
      """
    Then resource "<function_name>" of type "functions.mindwm.io/v1beta1" has a status "Ready" equal "True" in "<namespace>" namespace
    Then the configmap "mindwm-function-<function_name>-configmap" should exists in namespace "<namespace>"
    Then resource "mindwm-function-<function_name>-build-and-push" of type "pipelineruns.tekton.dev/v1" has a status "Succeeded" equal "True" in "<namespace>" namespace, timeout = "180"
    And container "step-pack-build" in pod "mindwm-function-<function_name>-build-and-push-buildpack-pod" in namespace "<namespace>" should contain "Successfully built image" regex
    Then image "/<namespace>/<function_name>" with tag "latest" should exists in "<registry_host>" registry
    When God creates "mindwm-function-test" resource of type "services.serving.knative.dev/v1" in the "<namespace>" namespace
    """
    apiVersion: serving.knative.dev/v1
    kind: Service
    metadata:
      name: knative-function-test
    spec:
      template:
        spec:
          containers:
          - image: zot-int.zot.svc.cluster.local:5000/context-cyan/yyy:latest
    """
    Then resource "knative-function-test" of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "<namespace>" namespace

    When God creates a new cloudevent
      And sets cloudevent header "ce-subject" to "#ping"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "ce-source" to "org.mindwm.alice.localhost.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sends cloudevent to knative service "knative-function-test" in "<namespace>" namespace
      """
      {
        "input": "",
        "output": "function log(msg) {console.log(msg);}",
        "ps1": "❯",
        "type": "org.mindwm.v1.iodocument"
      }
      """
      Then the response http code should be "200"

    Examples:
      | namespace | function_name | registry_host                       |
      | context-cyan   | yyy           | zot-int.zot.svc.cluster.local:5000  |

  Scenario: Check that Node-RED contains the expected tabs for context,user,host xrd resources
    Then cluster resource "<resource_name>" of type "disposablerequests.http.crossplane.io/v1alpha2" has a status "Ready" equal "True"
    Examples:
      | resource_name                 |
      | context-cyan-tab              |
      | context-cyan-user-bob-tab     |

  Scenario: Check that Node-RED contains the expected tabs for context,user,host xrd resources
    Then node-red should have a tab named "<tab_name>" in context "cyan"
    Examples:
      | tab_name                  |
      | context-cyan              |
      | user-bob                  |

  Scenario: Delete Resources and Verify Cleanup

    When God deletes mindwm function "<function_name>" in the "<namespace>" namespace
    Then the mindwm function "<function_name>" in the "<namespace>" namespace should be deleted


    When God deletes the MindWM host resource "workstation"
    Then the host "workstation" should be deleted

    When God deletes the MindWM user resource "bob"
    Then the user "bob" should be deleted
    And namespace "user-bob" should not exist

    When God deletes the MindWM context resource "cyan"
    Then the context "cyan" should be deleted
    And namespace "context-cyan" should not exist
    Examples:
      | namespace | function_name | registry_host                       |
      | context-cyan   | yyy           | zot-int.zot.svc.cluster.local:5000  |
