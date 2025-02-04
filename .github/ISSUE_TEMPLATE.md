---
title: "[nightly-build] fails"
assignees: metacoma
labels: nightly-build, need-triage, github-actions, tests
---
Someone just pushed, oh no! Here's who did it: {{ payload.sender.login }}.

junit:

total = {{ env.JUNIT_TOTAL }}

passed = {{ env.JUNIT_PASSED }}

skipped = {{ env.JUNIT_SKIPPED }}

retried = {{ env.JUNIT_RETRIED }}

failed = {{ env.JUNIT_FAILED }}

####

summary

{{ env.JUNIT_SUMMARY }}

#### 

detailed summary

{{ env.JUNIT_DETAILED_SUMMARY }}

###

flaky summary

{{ env.JUNIT_FLAKY_SUMMARY }}

