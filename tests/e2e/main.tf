terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "2.39.0"
    }
  }
}

variable linode_token {
    description = "Linode token"
    sensitive = true
} 

variable root_password {
    description = "root password"
    sensitive = true
} 

variable node_name {
    description = "vm node name"
    sensitive = false
}

# Configure the Linode Provider
provider "linode" {
  token = var.linode_token
}


resource "linode_instance" "ci" {
  label           = "${var.node_name}"
  image           = "linode/ubuntu24.04"
  region          = "nl-ams"
  type            = "g6-standard-6"
  authorized_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZu5HNWRwNF05fROu+QjEM1KANXkuDMZAuroU4jzqhx"]
  root_pass       = var.root_password

  tags       = ["mindwm-ci"]
  swap_size  = 0
  private_ip = true

  metadata {
    user_data = base64encode(file("./cloud-init.yaml"))
  }

}
output "ci_instance_ip" {
  description = "The public IP address of the CI instance"
  value       = linode_instance.ci.ip_address
}

