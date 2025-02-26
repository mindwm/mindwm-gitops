#!/usr/bin/env bash

function_name=`cat func.yaml | yq '.name'`
build_namespace=`cat func.yaml | yq '.namespace'`
deploy_namespace=`cat func.yaml | yq '.deploy.namespace'`
registry=`cat func.yaml | yq '.registry'`
image=`cat func.yaml | yq '.image'`
deploy_image=`cat func.yaml | yq '.deploy.image'`

generate_configmap_name() {
  dir=$1
  if [ "${dir}" == "." ]; then
    echo "mindwm-function-${function_name}"
    return
  fi
  suffix=`echo ${dir} | sed 's,^\./,,;s,/,-,g'`
  echo "mindwm-function-${function_name}-${suffix}"
}

create_configmap() {
  local dir=$1
  local configmap_name=$(generate_configmap_name ${dir})
  kubectl -n ${build_namespace} get configmap ${configmap_name} >/dev/null 2>&1 && kubectl -n ${build_namespace} delete configmap ${configmap_name}
  kubectl -n ${build_namespace} create configmap ${configmap_name} --from-file=${dir}
} 

generate_tekton_pipepline() {
cat<<EOF 
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: ${function_name}-build-run
spec:
  pipelineSpec:
    workspaces:
EOF
for dir in `find . -type d ! -name ".func"`; do
  configmap_name_with_source=$(generate_configmap_name ${dir})
  workspace=$(echo ${configmap_name_with_source} | sed "s,mindwm-function-${function_name}-,,")
cat<<EOF
    - name: ${workspace}
EOF
done
cat<<EOF
    - name: build
    tasks:
      - name: copy
        taskSpec:
          steps:
          - name: copy-app-files
            image: busybox
            script: |
              #!/bin/sh
              find /workspace
EOF
for dir in `find . -type d ! -name ".func"`; do
  configmap_name_with_source=$(generate_configmap_name ${dir})
  #if [ "${configmap_name_with_source}" == "" ]; then
  src=$(echo ${configmap_name_with_source} | sed "s,mindwm-function-${function_name}-,,")
  if [ "${dir}" == "." ]; then
    # src=$(echo ${configmap_name_with_source} | sed "s,mindwm-function-${function_name}-,,")
    dst="/workspace/build/"
  else
    #src=$(echo ${configmap_name_with_source} | sed "s,mindwm-function-${function_name}-,,")
    dst="/workspace/build/${src}"
  fi
cat<<EOF            
              test -d ${dst} || mkdir -p ${dst}
              cp -v /workspace/${src}/* ${dst}
EOF
done
cat<<EOF
        workspaces:
EOF
for dir in `find . -type d ! -name ".func"`; do
  configmap_name_with_source=$(generate_configmap_name ${dir})
  workspace=$(echo ${configmap_name_with_source} | sed "s,mindwm-function-${function_name}-,,")
cat<<EOF
          - name: ${workspace}
            workspace: ${workspace}
EOF
done
cat<<EOF
          - name: build
            workspace: build
      - name: buildpack
        params:
          - name: REGISTRY_ENDPOINT
            value: ${registry}
        taskSpec:
          steps:
            - name: pack-build
              env:
                - name: CNB_INSECURE_REGISTRIES 
                  value: ${registry}
              image: buildpacksio/pack:latest
              workingDir: /workspace/build
              command: 
                - pack
                - build
                - ${image}
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
EOF
for dir in `find . -type d ! -name ".func"`; do
  configmap_name_with_source=$(generate_configmap_name ${dir})
  workspace=$(echo ${configmap_name_with_source} | sed "s,mindwm-function-${function_name}-,,")
cat<<EOF
  - name: ${workspace}
    configMap:
      name: ${configmap_name_with_source}
EOF
done
}


for dir in `find . -type d ! -name ".func"`; do
  create_configmap $dir
done

kubectl -n ${build_namespace} delete PipelineRun ${function_name}-build-run

generate_tekton_pipepline | tee ./manifest.yaml | kubectl -n ${build_namespace} apply -f -
