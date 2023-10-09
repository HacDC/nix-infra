# TODO: Modularization
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# Helpers to get the current caller id and region
data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

locals {
  aws_region     = data.aws_region.current.name
  # TODO: hack
  aws_az = "${data.aws_region.current.name}b"
}

variable "ssh_public_key" {
  description = "Local ssh key"
  type        = string
  sensitive   = true
}

resource "aws_key_pair" "deploy_key" {
  key_name   = "deploy_key"
  public_key = var.ssh_public_key
}

variable "factorio_game_password" {
  description = "In-game factorio password"
  type        = string
  sensitive   = true
}

resource "aws_ssm_parameter" "factorio_game_password" {
  name        = "/factorio/game_password"
  description = "Game password for factorio"
  type        = "SecureString"
  value       = var.factorio_game_password
}

data "aws_iam_policy_document" "factorio_ssm_policy_document" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      aws_ssm_parameter.factorio_game_password.arn
    ]
  }
}

resource "aws_iam_policy" "factorio_ssm_policy" {
  name        = "factorio_ssm_policy"
  path        = "/"
  description = "Allow instance server to read SSM secrets"
  policy      = data.aws_iam_policy_document.factorio_ssm_policy_document.json
}

data "aws_iam_policy_document" "factorio_service_role_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "factorio_service_role" {
  name               = "factorio_service_role"
  assume_role_policy = data.aws_iam_policy_document.factorio_service_role_document.json
}

resource "aws_iam_role_policy_attachment" "factorio_ssm_policy_attachment" {
  role       = aws_iam_role.factorio_service_role.name
  policy_arn = aws_iam_policy.factorio_ssm_policy.arn
}

# Allow instance to access some limited AWS resouces
resource "aws_iam_instance_profile" "factorio_iam_instance_profile" {
  name = "factorio_iam_instance_profile"
  role = aws_iam_role.factorio_service_role.name
}

resource "aws_instance" "factorio_instance" {
  ami                         = "ami-07df5833f04703a2a"
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deploy_key.key_name
  availability_zone           = local.aws_az
  iam_instance_profile        = aws_iam_instance_profile.factorio_iam_instance_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }
}

output "factorio_ip" {
  value = aws_instance.factorio_instance.public_ip
}

# Ensure that the instance is reachable via `ssh` before deploying
# resource "null_resource" "wait" {
#   provisioner "remote-exec" {
#     connection {
#       user = "root"
#       host = "factorio"
#     }
#     inline = [":"]
#   }
#   depends_on = [aws_instance.factorio_instance]
# }
# 
# locals {
#   ssh_opts = "-o StrictHostKeyChecking=no"
# }
# 
# resource "null_resource" "deploy" {
#   provisioner "local-exec" {
#     command = "deploy --ssh-opts=\"${local.ssh_opts}\" ${path.module}#factorio"
#   }
#   depends_on = [null_resource.wait]
# }
