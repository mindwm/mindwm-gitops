@mindwm_knative_function
@mindwm_test
Feature: Mindwm event driven architecture

  Background:
    Given a kubernetes cluster
    Then all nodes in Kubernetes are ready

  Scenario: Create configmap with knative function definition
    When God creates the namespace "<namespace>"
    Then namespace "<namespace>" should exist
    When God applies kubernetes manifest in the "<namespace>" namespace
    """
    apiVersion: v1
    data:
      .funcignore: |2
        filestoignore
      .gitignore: |2
        /.func
      Procfile: |
        web: python -m parliament .
      README.md: |
        README
      app.sh: |
        #!/bin/sh

        exec python -m parliament "$(dirname "$0")"
      func.py: |
        from parliament import Context
        from flask import Request
        import json


        # parse request body, json data or URL query parameters
        def payload_print(req: Request) -> str:
            if req.method == "POST":
                if req.is_json:
                    return json.dumps(req.json) + "\n"
                else:
                    # MultiDict needs some iteration
                    ret = "{"

                    for key in req.form.keys():
                        ret += '"' + key + '": "'+ req.form[key] + '", '

                    return ret[:-2] + "}\n" if len(ret) > 2 else "{}"

            elif req.method == "GET":
                # MultiDict needs some iteration
                ret = "{"

                for key in req.args.keys():
                    ret += '"' + key + '": "' + req.args[key] + '", '

                return ret[:-2] + "}\n" if len(ret) > 2 else "{}"


        # pretty print the request to stdout instantaneously
        def pretty_print(req: Request) -> str:
            ret = str(req.method) + ' ' + str(req.url) + ' ' + str(req.host) + '\n'
            for (header, values) in req.headers:
                ret += "  " + str(header) + ": " + values + '\n'

            if req.method == "POST":
                ret += "Request body:\n"
                ret += "  " + payload_print(req) + '\n'

            elif req.method == "GET":
                ret += "URL Query String:\n"
                ret += "  " + payload_print(req) + '\n'

            return ret


        def main(context: Context):
            # Add your business logic here
            print("Received request")

            if 'request' in context.keys():
                ret = pretty_print(context.request)
                print(ret, flush=True)
                return payload_print(context.request), 200
            else:
                print("Empty request", flush=True)
                return "{}", 200
      func.yaml: |
        specVersion: 0.36.0
        name: mindwm-function
        runtime: python
        created: 2024-12-17T21:55:03.525539663+01:00
      requirements.txt: |
        parliament-functions==0.1.0
      test_func.py: |
        import unittest

        func = __import__("func")

        class TestFunc(unittest.TestCase):

          def test_func_empty_request(self):
            resp, code = func.main({})
            self.assertEqual(resp, "{}")
            self.assertEqual(code, 200)

        if __name__ == "__main__":
          unittest.main()
    kind: ConfigMap
    metadata:
      name: test-function
    """
    Then the configmap "<configmap_name>" should exists in namespace "<namespace>"
    #When God applies kubernetes manifest in the "<namespace>" namespace
    When God creates "mindwm-function-build-run" resource of type "pipelineruns.tekton.dev/v1beta1" in the "<namespace>" namespace
    """
    apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      name: mindwm-function-build-run
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      pipelineSpec:
        workspaces:
        - name: build
        - name: source
        tasks:
          - name: copy
            taskSpec:
              steps:
              - name: copy-app-files
                image: busybox
                script: |
                  #!/bin/sh
                  cp -vLr /workspace/source/* /workspace/build
            workspaces:
              - name: source
                workspace: source
              - name: build
                workspace: build
          - name: buildpack
            params:
              - name: REGISTRY_ENDPOINT
                value: zot-int.zot.svc.cluster.local:5000
            taskSpec:
              steps:
                - name: pack-build
                  env:
                    - name: CNB_INSECURE_REGISTRIES
                      value: zot-int.zot:5000;zot.zot.svc.cluster.local:5000
                  image: buildpacksio/pack:latest
                  workingDir: /workspace/build
                  command:
                    - pack
                    - build
                    - $(params.REGISTRY_ENDPOINT)/test3:latest
                    - --builder
                    - gcr.io/buildpacks/builder:google-22
                    - --workspace
                    - /workspace/build
                    - --docker-host=inherit
                    - --publish
                  securityContext:
                    privileged: true
                    runAsUser: 0
                    runAsGroup: 0
                    allowPrivilegeEscalation: true
                    capabilities:
                      add: ["ALL"]
                  volumeMounts:
                    - name: docker-socket
                      mountPath: /var/run/docker.sock
              volumes:
                  - name: docker-socket
                    hostPath:
                      path: /var/run/docker.sock
                      type: Socket

            workspaces:
              - name: build
                workspace: build
      workspaces:
      - name: build
        subPath: source
        volumeClaimTemplate:
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 1Gi
      - name: source
        configMap:
          name: test-function
    """
    Then resource "mindwm-function-build-run" of type "pipelineruns.tekton.dev/v1" has a status "Succeeded" equal "True" in "<namespace>" namespace, timeout = "180"
    And container "step-pack-build" in pod "mindwm-function-build-run-buildpack-pod" in namespace "<namespace>" should contain "Successfully built image" regex
    # TODO @(metacoma) use zot-int.zot.svc.clusetr.local:5000
    Then image "test3" with tag "latest" should exists in "<registry_domain>:5000" registry
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
            - image: zot-int.zot.svc.cluster.local:5000/test3:latest
    """
    Then resource "knative-function-test" of type "services.serving.knative.dev/v1" has a status "Ready" equal "True" in "<namespace>" namespace
    Examples:
    | namespace     | configmap_name | registry_domain |
    | test-function | test-function  | zot-int.zot.svc.cluster.local |
  Scenario: Send ping message to the service
    When God creates a new cloudevent
      And sets cloudevent header "ce-subject" to "#ping"
      And sets cloudevent header "ce-type" to "org.mindwm.v1.iodocument"
      And sets cloudevent header "ce-source" to "org.mindwm.alice.localhost.L3RtcC90bXV4LTEwMDAvZGVmYXVsdA==.09fb195c-c419-6d62-15e0-51b6ee990922.23.36.iodocument"
      And sends cloudevent to knative service "knative-function-test" in "test-function" namespace
      """
      {
        "input": "#ping",
        "output": "",
        "ps1": "❯",
        "type": "org.mindwm.v1.iodocument"
      }
      """
      Then the response http code should be "200"

    Then the following deployments are in a ready state in the "<namespace>" namespace
      | Deployment name                        |
      | knative-function-test-00001-deployment |

    And container "user-container" in pod "knative-function-test-00001-deployment-.*" in namespace "<namespace>" should contain "ping" regex

    And container "user-container" in pod "^.*-00001-deployment-.*" in namespace "<namespace>" should not contain "Traceback \(most recent call last\):" regex

    Examples:
    | namespace     | configmap_name |
    | test-function | test-function  |

  Scenario: cleanup
    When God deletes the namespace "<namespace>"
    Then namespace "<namespace>" should not exist
    Examples:
    | namespace     | configmap_name |
    | test-function | test-function  |
