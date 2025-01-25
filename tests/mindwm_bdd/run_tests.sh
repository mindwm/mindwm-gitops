#!/usr/bin/env sh
ARTIFACT_DIR=artifact_dir
. .venv/bin/activate
pip3 install -r requirements.txt
#pytest -s --md-report --md-report-tee --md-report-verbose=7  --md-report-tee --md-report-output=${ARTIFACT_DIR}/report.md --kube-config=${HOME}/.kube/config --alluredir ${ARTIFACT_DIR}/allure-results . --order-dependencies
#pytest -s -x -m two_hosts_one_user --disable-warnings --no-header -vv --gherkin-terminal-reporter --kube-config=${HOME}/.kube/config --alluredir=${ARTIFACT_DIR}/allure-results
pytest -s -m "$*" -x --disable-warnings --no-header -vv --gherkin-terminal-reporter --kube-config=${HOME}/.kube/config --alluredir=${ARTIFACT_DIR}/allure-results
