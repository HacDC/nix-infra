variable "terraria_password" {
  description = "In-game terraria password"
  type        = string
  sensitive   = true
}

resource "aws_ssm_parameter" "terraria_password" {
  name        = "/terraria/password"
  description = "In game password for terraria"
  type        = "SecureString"
  value       = var.terraria_password
}

data "aws_iam_policy_document" "terraria_ssm_policy_document" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [ aws_ssm_parameter.terraria_password.arn ]
  }
}

resource "aws_iam_policy" "terraria_ssm_policy" {
  name        = "terraria_ssm_policy"
  path        = "/"
  description = "Allow instance server to read SSM secrets"
  policy      = data.aws_iam_policy_document.terraria_ssm_policy_document.json
}

data "aws_iam_policy_document" "terraria_service_role_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "terraria_service_role" {
  name               = "terraria_service_role"
  assume_role_policy = data.aws_iam_policy_document.terraria_service_role_document.json
}

resource "aws_iam_role_policy_attachment" "terraria_ssm_policy_attachment" {
  role       = aws_iam_role.terraria_service_role.name
  policy_arn = aws_iam_policy.terraria_ssm_policy.arn
}

# Allow instance to access some limited AWS resouces
resource "aws_iam_instance_profile" "terraria_iam_instance_profile" {
  name = "terraria_iam_instance_profile"
  role = aws_iam_role.terraria_service_role.name
}

resource "aws_instance" "terraria_instance" {
  ami                         = "ami-07df5833f04703a2a"
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deploy_key.key_name
  availability_zone           = local.aws_az
  iam_instance_profile        = aws_iam_instance_profile.terraria_iam_instance_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }
}

output "terraria_ip" {
  value = aws_instance.terraria_instance.public_ip
}
