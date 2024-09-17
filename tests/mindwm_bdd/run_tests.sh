#!/usr/bin/env sh
ARTIFACT_DIR=artifact_dir
source .venv/bin/activate
. .venv/bin/activate
#pytest -s --md-report --md-report-tee --md-report-verbose=7  --md-report-tee --md-report-output=${ARTIFACT_DIR}/report.md --kube-config=${HOME}/.kube/config --alluredir ${ARTIFACT_DIR}/allure-results . --order-dependencies
pytest -s -m lifecycle --disable-warnings --no-header -vv --gherkin-terminal-reporter --kube-config=${HOME}/.kube/config --alluredir=${ARTIFACT_DIR}/allure-results 
