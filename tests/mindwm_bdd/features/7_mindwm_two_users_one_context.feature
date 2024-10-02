@mindwm_two_users_one_context
@mindwm_test
Feature: MindWM two users one context function test
  Background:
    Given A MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Create context <context>
    When God creates a MindWM context with the name "<context>"
    Then the context should be ready and operable

    Then following knative service is in ready state in "context-<context>" namespace
      | Knative service name |
      | iocontext            |
      | pong                 |
      | kafka-cdc            |
    And statefulset "<context>-neo4j" in namespace "context-<context>" is in ready state
    Examples:
    | context | 
    | tokyo   | 
    
  Scenario: Create <username> and connects it to <context>
    When God creates a MindWM user resource with the name "<username>" and connects it to the context "<context>"
    Then the user resource should be ready and operable
    Examples:
    | context | username |
    | tokyo   | godzilla |
    | tokyo   | tengu    |
  Scenario: Create <host> resource and connects it to <username> user
    When God creates a MindWM host resource with the name "<host>" and connects it to the user "<username>"
    Then the host resource should be ready and operable

    Examples: 
    | username | host   |
    | godzilla | laptop | 
    | tengu    | tablet | 

  Scenario: Cleanup <host> host for <username> username

    When God deletes the MindWM host resource "<host>"
    Then the host "<host>" should be deleted

    Examples:
    | username | host   |
    | godzilla | laptop | 
    | tengu    | tablet | 

  Scenario: Cleanup <username> username
    When God deletes the MindWM user resource "<username>"
    Then the user "<username>" should be deleted

    Examples:
    | username | 
    | godzilla |
    | tengu    | 

  Scenario: Cleanup <context> context
    When God deletes the MindWM context resource "<context>"
    Then the context "<context>" should be deleted

    Examples:
    | context | 
    | tokyo   |
