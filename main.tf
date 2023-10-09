# TODO: Modularization

data "aws_vpc" "default" {
  default = true
}

module "factorio" {
  source = "./modules/instance"
  hostname = "factorio"
  aws_az = local.aws_az
  instance_type = "t3.micro"
}

# Ensure that the instance is reachable via `ssh` before deploying
resource "null_resource" "wait" {
  provisioner "remote-exec" {
    connection {
      user = "root"
      host = "factorio"
    }

    inline = [":"]
  }
  depends_on = [module.factorio]
}

locals {
  ssh_opts = "-o StrictHostKeyChecking=no"
}

resource "null_resource" "deploy" {
  provisioner "local-exec" {
    command = "deploy --ssh-opts=\"${local.ssh_opts}\" ${path.module}#factorio"
  }

  depends_on = [null_resource.wait]
}
