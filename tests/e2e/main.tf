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
    description = "root password"
    sensitive = true
} 

variable git_repository {
    description = "git repo"
    sensitive = false
} 

variable git_commit_sha {
    description = "git commit sha"
    sensitive = false
} 
variable git_ref_name {
    description = "branch name"
    sensitive = false
} 

# Configure the Linode Provider
provider "linode" {
  token = var.linode_token
}

resource "linode_instance" "ci" {
  label           = "mindwm-ci-${var.git_commit_sha}"
  image           = "linode/ubuntu24.04"
  region          = "nl-ams"
  type            = "g6-standard-6"
  authorized_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZu5HNWRwNF05fROu+QjEM1KANXkuDMZAuroU4jzqhx"]
  root_pass       = var.root_password

  tags       = ["mindwm-ci", "${var.git_commit_sha}"]
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
        "echo 0 > /tmp/exit_code",
        "echo XXX > /tmp/report.md"
#        "git clone -b ${var.git_ref_name} https://github.com/${var.git_repository}",
#        "timeout 90 bash -c 'while :; do docker info && break; sleep 1; echo -n .; done'",
#        "echo dir: `basename ${var.git_repository}` checkout ${var.git_commit_sha} TARGET_REVISION=${var.git_ref_name}",
#        "cd `basename ${var.git_repository}` && make mindwm_lifecycle mindwm_test TARGET_REVISION=${var.git_ref_name} || echo $? > /tmp/exit_code" ,

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

