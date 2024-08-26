terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
    }
  }
}

variable linode_token {
    description = "Linode token"
    sensitive = true
} 

variable ssh_private_key {
    description = "ssh private key"
    sensitive = true
} 

variable root_password {
    description = "ssh private key"
    sensitive = true
} 

# Configure the Linode Provider
provider "linode" {
  token = var.linode_token
}

resource "linode_instance" "ci" {
  label           = "mindwm-ci"
  image           = "linode/ubuntu24.04"
  region          = "nl-ams"
  type            = "g6-standard-6"
  authorized_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZu5HNWRwNF05fROu+QjEM1KANXkuDMZAuroU4jzqhx"]
  root_pass       = var.root_password

  tags       = ["mindwm-ci"]
  swap_size  = 0
  private_ip = true

  connection {
    type     = "ssh"
    user     = "ci"
    host     = linode_instance.ci.ip_address
    private_key = var.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
        "git clone https://github.com/mindwm/mindwm-gitops",
        "timeout 90 bash -c 'while :; do docker info && break; sleep 1; echo -n .; done'",
        "cd mindwm-gitops && make mindwm_lifecycle",
    ]
  }
  metadata {
    user_data = base64encode(file("./cloud-init.yaml"))
  }

}
output "ci_instance_ip" {
  description = "The public IP address of the CI instance"
  value       = linode_instance.ci.ip_address
}
