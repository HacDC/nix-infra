variable "hostname" {
  type = string
}

variable "flake_path" {
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

locals {
  state_device_name = "/dev/sdf"
  ami_device = [
    for d in data.aws_ami.nix_tailscale.block_device_mappings : d
    if d.device_name == local.state_device_name
  ][0]
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

  ephemeral_block_device {
    device_name = local.state_device_name
    no_device   = true
  }
}

# Manage the state device separately from the instance AMI to avoid
# recreation if the instance is recreated.
# TODO: Test this better
# TODO: Importing an existing disk
resource "aws_ebs_volume" "instance" {
  availability_zone = var.aws_az
  snapshot_id       = local.ami_device.ebs.snapshot_id
  type              = local.ami_device.ebs.volume_type
}

resource "aws_volume_attachment" "instance" {
  device_name = local.state_device_name
  volume_id   = aws_ebs_volume.instance.id
  instance_id = aws_instance.instance.id
}

# Ensure that the instance is reachable via `ssh` before deploying
resource "null_resource" "wait" {
  provisioner "remote-exec" {
    connection {
      user = "root"
      host = "instance"
    }

    inline = [":"]
  }
}

local {
  ssh_opts = "-o StrictHostKeyChecking=accept-new"
}

resource "null_resource" "deploy" {
  provisioner "local-exec" {
    command = "deploy --ssh-opts=\"${ssh_opts}\" ${var.flake_path}#${var.hostname}"
  }

  depends_on = [null_resource.wait]
}
