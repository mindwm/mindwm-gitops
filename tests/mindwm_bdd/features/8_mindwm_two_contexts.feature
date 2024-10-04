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

    # Verify Deployments
    And the following deployments are in a ready state in the "context-<context>" namespace
      | Deployment name               |
      | kafka-cdc-00001-deployment    |
      | iocontext-00001-deployment    |

    # Verify StatefulSets
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state

    # Verify Knative Services
    And the following knative services are in a ready state in the "context-<context>" namespace
      | Knative service name |
      | iocontext            |
      | kafka-cdc            |
      | dead-letter          |
      | pong                 |

    # Verify Knative Triggers
    And the following knative triggers are in a ready state in the "context-<context>" namespace
      | Knative trigger name          |
      | iocontext-trigger             |
      | kafka-cdc-trigger             |
      | pong-trigger                  |

    # Verify Knative Brokers
    And the following knative brokers are in a ready state in the "context-<context>" namespace
      | Knative broker name           |
      | context-broker                |

    # Verify Kafka Topics and Sources
    And kafka topic "context-<context>-cdc" is in ready state in "redpanda" namespace
    And kafka source "context-<context>-cdc-kafkasource" is in ready state in "context-<context>" namespace


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

