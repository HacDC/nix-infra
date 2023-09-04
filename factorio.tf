data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "factorio" {
  name        = "factorio-sg"
  description = "Firewall config for Factorio server"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "factorio_allow_ssh_ingress" {
  type              = "ingress"
  description       = "allow ssh"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.factorio.id
}

resource "aws_security_group_rule" "factorio_allow_all_egress" {
  type              = "egress"
  description       = "allow all"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.factorio.id
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
  policy = data.aws_iam_policy_document.factorio_policy.json
}

data "aws_iam_policy_document" "factorio_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "factorio" {
  name = "factorio_role"
  assume_role_policy = data.aws_iam_policy_document.factorio_role.json
}

resource "aws_iam_role_policy_attachment" "factorio" {
  role       = aws_iam_role.factorio.name
  policy_arn = aws_iam_policy.factorio.arn
}

resource "aws_iam_instance_profile" "factorio" {
  name = "factorio_profile"
  role = aws_iam_role.factorio.name
}

resource "aws_instance" "factorio" {
  ami                    = "ami-04dd958576800a442" # "ami-07df5833f04703a2a"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deploy_key.key_name
  availability_zone      = local.aws_az
  iam_instance_profile   = aws_iam_instance_profile.factorio.name
  vpc_security_group_ids = [aws_security_group.factorio.id]
  # Do not create until the ssm parameter has been created
  depends_on = [aws_ssm_parameter.factorio_tailnet_key]

  # root_block_device {
  #   volume_size = 8
  # }

  # user_data = <<-EOT
  #   #!/usr/bin/env bash
  #   nix-shell -p bash util-linux e2fsprogs --run bash <<'EOF'
  #     set -e

  #     function wait_for() {
  #       drive="$1"
  #       until [ -e "$drive" ]; do
  #         echo "Waiting for $drive to be ready..."
  #         sleep 1
  #       done
  #       echo "Device $drive ready"
  #     }

  #     fallocate -l 1G /swapfile
  #     chmod 600 /swapfile
  #     mkswap /swapfile
  #     swapon /swapfile

  #     drive="/dev/sdf"
  #     wait_for "$drive"
  #     if [ "ext4" != "$(blkid -o value -s TYPE "$drive")" ]; then
  #       mkfs -t ext4 -L state "$drive"
  #     fi

  #     drive="/dev/disk/by-label/state"
  #     wait_for "$drive"
  #     mkdir /state
  #     mount "$drive" /state
  #   EOF
  # EOT
}

# resource "aws_ebs_volume" "factorio" {
#   availability_zone = local.aws_az
#   size              = 2
# }
# 
# resource "aws_volume_attachment" "factorio" {
#   device_name = "/dev/sdf"
#   volume_id   = aws_ebs_volume.factorio.id
#   instance_id = aws_instance.factorio.id
# }

output "factorio_ip_addr" {
  value = aws_instance.factorio.public_ip
}
