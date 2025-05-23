@fake_test
Feature: Fake test

  Scenario: Create mindwm-function
    When God creates a MindWM function resource with the name "func1" in the "test" namespace
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
    Then the mindwm function "func1" in the "test" namespace should be ready and operable
    When God deletes mindwm function "func1" in the "test" namespace
    Then the mindwm function "<function_name>" in the "<namespace>" namespace should be deleted
    #Then the mindwm function "func1" in the "test" namespace should be deleted
  #   Scenario: Fake test
  #     Then the directory '/tmp' should exist
  #
  # Scenario: Check that Node-RED contains the expected tabs for context,user,host xrd resources
  #   Then cluster resource "<resource_name>" of type "disposablerequests.http.crossplane.io/v1alpha2" has a status "Ready" equal "True"
  #   Examples:
  #     | resource_name                 |
  #     | context-cyan-tab              |
  #     | context-cyan-user-bob-tab     |
