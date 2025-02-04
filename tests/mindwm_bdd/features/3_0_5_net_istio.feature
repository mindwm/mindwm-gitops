@mindwm_net_istio
@mindwm_test

Feature: Knative-Serving net-istio

  Background:
    Given a MindWM environment
    Then all nodes in Kubernetes are ready

  Scenario: Check net-istio pods
    Then the following deployments are in a ready state in the "knative-serving" namespace
      | Deployment name      |
      | net-istio-controller |
      | net-istio-webhook    |
    And pods matching the label "app=net-istio-controller" in "knative-serving" namespace, have an age greater than 300
    And pods matching the label "app=net-istio-webhook" in "knative-serving" namespace, have an age greater than 300
