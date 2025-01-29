@mindwm_two_contexts
@mindwm_test
Feature: Context Resource Readiness and Cleanup Verification

  Background:
    Given a MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario Outline: Create Contexts and Verify All Related Resources Are in Ready State
    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable

    # Verify Namespace
    And namespace "context-<context>" should exist

    And the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name               |
      | kafka-cdc-00001-deployment    |
      | iocontext-00001-deployment    |
      | clipboard-00001-deployment    |

    And the following resources of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace
      | Knative service name |
      | dead-letter          |
      | clipboard            |
      | iocontext            |
      | kafka-cdc            |
      | pong                 |

    # Verify StatefulSets
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    # Verify Knative Triggers
    And the following resources of type "triggers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace
      | Knative trigger name |
      | iocontext-trigger    |
      | kafka-cdc-trigger    |
      | pong-trigger         |
      | clipboard-trigger    |

    # Verify Knative Brokers
    And resource "context-broker" of type "brokers.eventing.knative.dev/v1" has a status "Ready" equal "True" in "context-<context>" namespace

    # Verify Kafka Topics and Sources
    And resource "context-<context>-cdc" of type "topics.cluster.redpanda.com/v1alpha2" has a status "Ready" equal "True" in "redpanda" namespace
    And resource "context-<context>-cdc-kafkasource" of type "kafkasources.sources.knative.dev/v1beta1" has a status "Ready" equal "True" in "context-<context>" namespace

    Examples:
      | context   |
      | aphrodite |
      | kypros    |

  Scenario Outline: Cleanup Contexts and Verify Resources Are Deleted
    When God deletes the MindWM context resource "<context>"
    Then the context "<context>" should be deleted
    And namespace "context-<context>" should not exist

    Examples:
      | context   |
      | aphrodite |
      | kypros    |

