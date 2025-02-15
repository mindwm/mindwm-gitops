#!/usr/bin/env sh
ARTIFACT_DIR=artifact_dir
. .venv/bin/activate
#pip3 install -r requirements.txt
#pytest -s --md-report --md-report-tee --md-report-verbose=7  --md-report-tee --md-report-output=${ARTIFACT_DIR}/report.md --kube-config=${HOME}/.kube/config --alluredir ${ARTIFACT_DIR}/allure-results . --order-dependencies
#pytest -s -x -m two_hosts_one_user --disable-warnings --no-header -vv --gherkin-terminal-reporter --kube-config=${HOME}/.kube/config --alluredir=${ARTIFACT_DIR}/allure-results
pytest -s -x -m "$*" --junit-xml=${ARTIFACT_DIR}/report.xml --log-level info --disable-warnings --no-header -vv --gherkin-terminal-reporter --kube-config=${HOME}/.kube/config --alluredir=${ARTIFACT_DIR}/allure-results

# (time ./run_tests.sh eda) && (allure generate -c artifact_dir/allure-results && allure serve --host 0.0.0.0 --port 8080 allure-report)
