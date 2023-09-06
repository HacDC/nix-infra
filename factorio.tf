# TODO: Modularization

data "aws_vpc" "default" {
  default = true
}

resource "tailscale_tailnet_key" "factorio" {
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
}

resource "aws_ssm_parameter" "factorio_tailnet_key" {
  name        = "/factorio/tailscale/key"
  description = "AuthKey used to connect to the tailnet"
  type        = "SecureString"
  value       = tailscale_tailnet_key.factorio.key
}

data "aws_iam_policy_document" "factorio_policy" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      aws_ssm_parameter.factorio_tailnet_key.arn
    ]
  }
}

resource "aws_iam_policy" "factorio" {
  name        = "factorio_policy"
  path        = "/"
  description = "Allow factorio server to read SSM secrets"
  policy      = data.aws_iam_policy_document.factorio_policy.json
}

data "aws_iam_policy_document" "factorio_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "factorio" {
  name               = "factorio_role"
  assume_role_policy = data.aws_iam_policy_document.factorio_role.json
}

resource "aws_iam_role_policy_attachment" "factorio" {
  role       = aws_iam_role.factorio.name
  policy_arn = aws_iam_policy.factorio.arn
}

# Allow instance to access some limited AWS resouces
resource "aws_iam_instance_profile" "factorio" {
  name = "factorio_profile"
  role = aws_iam_role.factorio.name
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

resource "aws_instance" "factorio" {
  ami                         = data.aws_ami.nix_tailscale.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deploy_key.key_name
  associate_public_ip_address = false
  availability_zone           = local.aws_az
  iam_instance_profile        = aws_iam_instance_profile.factorio.name
  # Do not create until the ssm parameter has been created
  depends_on = [aws_ssm_parameter.factorio_tailnet_key]

  ephemeral_block_device {
    device_name = local.state_device_name
    no_device   = true
  }
}

# Manage the state device separately from the instance AMI to avoid
# recreation if the instance is recreated.
# TODO: Test this better
# TODO: Importing an existing disk
resource "aws_ebs_volume" "factorio" {
  availability_zone = local.aws_az
  snapshot_id       = local.ami_device.ebs.snapshot_id
  type              = local.ami_device.ebs.volume_type
}

resource "aws_volume_attachment" "factorio" {
  device_name = local.state_device_name
  volume_id   = aws_ebs_volume.factorio.id
  instance_id = aws_instance.factorio.id
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
}

resource "null_resource" "deploy" {
  provisioner "local-exec" {
    # interpreter = "nix develop ${path.module}# --command bash"
    command = "deploy ${path.module}#factorio"
  }

  depends_on = [null_resource.wait]
}
