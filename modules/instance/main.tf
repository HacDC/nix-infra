terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.13"
    }
  }

  required_version = ">= 1.2.0"
}

variable "hostname" {
  type = string
}

variable "aws_az" {
  type = string
}

variable "instance_type" {
  type = string
}


# Generate an SSH key pair as strings stored in Terraform state
resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

# Mirror the SSH public key to EC2 so that we can later install the public key
# as an authorized key for our server
resource "aws_key_pair" "deploy_key" {
  public_key = tls_private_key.deploy_key.public_key_openssh
}

resource "tailscale_tailnet_key" "instance" {
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
  tags          = ["tag:server"]
}

resource "aws_ssm_parameter" "instance_tailnet_key" {
  name        = "/${var.hostname}/tailscale/key"
  description = "AuthKey used to connect to the tailnet"
  type        = "SecureString"
  value       = tailscale_tailnet_key.instance.key
}

data "aws_iam_policy_document" "instance_policy" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      aws_ssm_parameter.instance_tailnet_key.arn
    ]
  }
}

resource "aws_iam_policy" "instance" {
  name        = "${var.hostname}_policy"
  path        = "/"
  description = "Allow instance server to read SSM secrets"
  policy      = data.aws_iam_policy_document.instance_policy.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.hostname}_role"
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

resource "aws_iam_role_policy_attachment" "instance" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance.arn
}

# Allow instance to access some limited AWS resouces
resource "aws_iam_instance_profile" "instance" {
  name = "${var.hostname}_profile"
  role = aws_iam_role.instance.name
}

data "aws_ami" "nix_tailscale" {
  owners      = ["self"]
  most_recent = true
  name_regex  = "nix-tailscale"
}

resource "aws_instance" "instance" {
  ami                         = data.aws_ami.nix_tailscale.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deploy_key.key_name
  associate_public_ip_address = false
  availability_zone           = var.aws_az
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  # Do not create until the ssm parameter has been created
  depends_on = [aws_ssm_parameter.instance_tailnet_key]

  root_block_device {
    volume_type = "gp3"
  }
}

# Manage the state device separately from the instance AMI to avoid
# recreation if the instance is recreated.
# TODO: Test this better
# TODO: Importing an existing disk
resource "aws_ebs_volume" "instance" {
  availability_zone = var.aws_az
  type = "gp3"
  size = 1
}

resource "aws_volume_attachment" "instance" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.instance.id
  instance_id = aws_instance.instance.id
}
