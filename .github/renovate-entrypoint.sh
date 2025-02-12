#!/bin/bash

apt update
bash <(curl -sL https://kcl-lang.io/script/install-cli.sh) 0.9.7
echo ---
find / | grep -i main.k
echo ---
mkdir -p ~/.git-templates/hooks
cat<<EOF | tee ~/.git-templates/hooks/post-checkout
#!/bin/bash
kcl run -o main.yaml
EOF
chmod +x ~/.git-templates/hooks/post-checkout
git config --global init.templateDir ~/.git-templates
runuser -u ubuntu renovate
