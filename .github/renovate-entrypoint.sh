#!/bin/bash

apt update
bash <(curl -sL https://kcl-lang.io/script/install-cli.sh) 0.9.7
echo ---
find / | grep -i main.k
echo ---
kcl run -o main.yaml
runuser -u ubuntu renovate
