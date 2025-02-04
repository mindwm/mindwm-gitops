---
title: "[nightly-build] {{ env.ISSUE_TITLE }}"
assignees: metacoma
labels: nightly-build, need-triage, github-actions, tests
---

{{ env.ALLURE_TEST_RESULT_ICON }} [Allure report]({{ env.ALLURE_REPORT_URL }})

{{ env.ALLURE_TEST_RESULT_ICON }} [Failed job]({{ env.GITHUB_FAILED_JOB_URL }})

summary

{{ env.JUNIT_SUMMARY }}

#### 

detailed summary

{{ env.JUNIT_DETAILED_SUMMARY }}

###

flaky summary

{{ env.JUNIT_FLAKY_SUMMARY }}

