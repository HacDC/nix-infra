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

locals {
  factorio_ssm_prefix           = "factorio"
  factorio_tailnet_ssm_prefix   = "${local.factorio_ssm_prefix}/tailscale"
  factorio_tailnet_key_ssm_path = "${local.factorio_tailnet_ssm_prefix}/key"
}

resource "aws_ssm_parameter" "factorio_tailnet_key" {
  name        = "/${local.factorio_tailnet_key_ssm_path}"
  description = "AuthKey used to connect to the tailnet"
  type        = "SecureString"
  value       = tailscale_tailnet_key.factorio.key
}

resource "aws_iam_policy" "factorio" {
  name        = "factorio_policy"
  path        = "/"
  description = "Allow factorio server to read SSM secrets"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:DescribeParameters",
          "ssm:GetParametersByPath"
        ],
        "Resource" : "arn:aws:ssm:${local.aws_region}:${local.aws_account_id}:parameter/${local.factorio_ssm_prefix}*"
      },
    ]
  })
}

resource "aws_iam_role" "factorio" {
  name = "factorio_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
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
  ami           = "ami-07df5833f04703a2a"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.mmazzanti.key_name
  availability_zone = local.aws_az
  user_data            = file("${path.module}/configuration.nix")
  iam_instance_profile = aws_iam_instance_profile.factorio.name
  vpc_security_group_ids = [aws_security_group.factorio.id]
  # Do not create until the ssm parameter has been created
  depends_on = [aws_ssm_parameter.factorio_tailnet_key]
}

resource "aws_ebs_volume" "factorio" {
  availability_zone = local.aws_az
  size              = 2
}

resource "aws_volume_attachment" "factorio" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.factorio.id
  instance_id = aws_instance.factorio.id
}

output "factorio_ip_addr" {
  value = aws_instance.factorio.public_ip
}
