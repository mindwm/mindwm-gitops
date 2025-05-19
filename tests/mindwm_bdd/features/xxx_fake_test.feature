@fake_test
Feature: Fake test
    Scenario: Fake test
      Then the directory '/tmp' should exist

  Scenario: Check that Node-RED contains the expected tabs for context,user,host xrd resources
    Then cluster resource "<resource_name>" of type "disposablerequests.http.crossplane.io/v1alpha2" has a status "Ready" equal "True"
    Examples:
      | resource_name                 |
      | context-cyan-tab              |
      | context-cyan-user-bob-tab     |
