#!/usr/bin/env bash

for language in go node python quarkus rust springboot typescript; do
  #echo ${language}
  templates="http cloudevents"
  if [ ${language} == "python" ]; then
    templates="${templates} flask wsgi"
  fi
  for template in $templates; do
    func_dir="test-function-${language}-${template}"
    func_name=${func_dir}
    image=test-function/${language}-${template}:latest
    registry=zot-int.zot.svc.cluster.local:5000
    test -d ${func_dir} && rm -rf ${func_dir}
    func create --language ${language} --template ${template} ${func_dir}
    func_yaml_temp=`mktemp /tmp/${func_dir}_XXXXXX`
    (
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' ${func_dir}/func.yaml - <<EOF
specVersion: 0.36.0
name: ${func_name}
runtime: ${language}
registry: ${registry}
image: ${registry}/${image}
namespace: default
deploy:
  namespace: default
  image: zot-int.zot.svc.cluster.local:5000/mindwm-function/mindwm-typescript:master
EOF
    ) > ${func_yaml_temp} 
    mv ${func_yaml_temp} ${func_dir}/func.yaml
    (
      cd ${func_dir}
      bash ../make_mindwm_function.sh
    )
  done

  # tempaltes="http cloudevent"
  # if $language == "python"; then
  #   tempaltes="$template wsgi flask"
  # fi
  # for template in "$templates"; do
  #   echo $template
  #   #func_dir="test-function-${language}-${template}"
  #   #echo ${func_dir}
  #   #test -d ${func_dir} && rm -rf ${func_dir}
  #   #func create --language ${language} --template ${template} ${func_dir}
  # done
done
