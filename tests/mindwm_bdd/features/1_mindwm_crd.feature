# Issue https://github.com/mindwm/mindwm-gitops/issues/100
@mindwm_crd
@mindwm_test
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

  Scenario: Create mindwm-function
    When God creates a MindWM function resource with the name "func1" in the "context-xxx3" namespace
    """
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
    Then the mindwm function "func1" in the "context-xxx3" namespace should be ready and operable

  Scenario: Delete Resources and Verify Cleanup
    When God deletes the MindWM host resource "laptop"
    Then the host "laptop" should be deleted
    When God deletes the MindWM user resource "alice"
    Then the user "alice" should be deleted
    Then the mindwm function "func1" in the "context-xxx3" namespace should be deleted
    When God deletes the MindWM context resource "xxx3"
    Then the context "xxx3" should be deleted
