# Deployment on Ubuntu 24.04


## Step 1: System Update
```bash
sudo apt-get update
```

## Step 2: Git Installation
```bash
sudo apt-get install git
```

## Step 3: Docker Installation (minimum docker server api version 1.4.6 required)
### 3.1 Set up Docker's apt repository
```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

### 3.2 Install Docker packages
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin  
cat<<EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:30001"]
}
EOF
```

### 3.3 Add user to the Docker group
```bash
sudo groupadd docker  
sudo usermod -aG docker $USER  
newgrp docker  
```

## Step 4: Make installation
```bash
sudo apt install make yq -y
```

## Step 5: Removing the need for a password to use sudo

### 5.1 Open a Terminal window and type
```bash
sudo visudo
```

### 5.2 On the bottom of the file, add the following line:
```bash
$USER ALL=(ALL) NOPASSWD: ALL
```

## Step 6: Launching the deployment
```bash
git clone https://github.com/mindwm/mindwm-gitops.git  
cd mindwm-gitops  
make mindwm_lifecycle  
```


