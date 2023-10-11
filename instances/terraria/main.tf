variable "aws_az" {
  description = "Name of aws availability zone to deploy to"
  type        = string
}

variable "dns_zone_id" {
  description = "Route 53 zone ID"
  type        = string
}

variable "key_name" {
  description = "Name of AWS SSH public key to install on system"
  type        = string
}

variable "deployer_ip" {
  description = "IP of deployer"
  type        = string
  sensitive   = true
}

variable "player_ips" {
  type = map(string)
}

variable "password" {
  description = "In-game terraria password"
  type        = string
  sensitive   = true
}

resource "aws_ssm_parameter" "password" {
  name        = "/terraria/password"
  description = "In game password for terraria"
  type        = "SecureString"
  value       = var.password
}

data "aws_iam_policy_document" "instance_policy" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DescribeParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [aws_ssm_parameter.password.arn]
  }
}

resource "aws_iam_policy" "instance" {
  name        = "terraria_ssm_policy"
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
  name               = "terraria_service_role"
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

resource "aws_iam_role_policy_attachment" "instance" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance.arn
}

# Allow instance to access some limited AWS resouces
resource "aws_iam_instance_profile" "instance" {
  name = "terraria_iam_instance_profile"
  role = aws_iam_role.instance.name
}

resource "aws_security_group" "instance" {
  name        = "terraria_security_group"
  description = "Allow deployers and players for factorio instance"

  ingress {
    description = "SSH From Deployer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.deployer_ip}/32"]
  }

  dynamic "ingress" {
    for_each = var.player_ips
    content {
      description = ingress.key
      from_port   = 7777
      to_port     = 7777
      protocol    = "udp"
      cidr_blocks = ["${ingress.value}/32"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "instance" {
  ami                    = "ami-07df5833f04703a2a"
  instance_type          = "t3.micro"
  key_name               = var.key_name
  availability_zone      = var.aws_az
  iam_instance_profile   = aws_iam_instance_profile.instance.name
  vpc_security_group_ids = [aws_security_group.instance.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "terraria"
  }
}

resource "aws_route53_record" "instance" {
  zone_id = var.dns_zone_id
  name    = "terraria.mmazzanti.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.instance.public_ip]
}

output "ip" {
  value = aws_instance.instance.public_ip
}
