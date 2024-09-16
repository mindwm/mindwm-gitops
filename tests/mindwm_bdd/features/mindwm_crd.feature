@crd
Feature: MindWM Custom Resource Definition

  Background:
    Given a MindWM environment
    
  Scenario: Create Context 
    When God creates a MindWM context with the name "xxx3"
    Then the context should be ready and operable

  Scenario: Create User 
    When God creates a MindWM user resource with the name "alice" and connects it to the context "xxx3"
    Then the user resource should be ready and operable

  Scenario: Create Host
    When God creates a MindWM host resource with the name "laptop" and connects it to the user "alice"
    Then the host resource should be ready and operable
