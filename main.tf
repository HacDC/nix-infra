terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }

    tailscale = {
      source = "tailscale/tailscale"
      version = "~> 0.13"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

provider "tailscale" {
  tailnet = "matthew.mazzanti@gmail.com"
}

resource "tailscale_tailnet_key" "factorio_key" {
  reusable      = false
  ephemeral     = false
  preauthorized = true
  expiry        = 3600
}

resource "aws_secretsmanager_secret" "factorio_secret" {
  name = "factorio_secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.factorio_secret.id
  secret_string = tailscale_tailnet_key.factorio_key.key
}

resource "aws_iam_policy" "factorio_policy" {
  name        = "factorio_policy"
  path        = "/"
  description = "Allow factorio server to read secrets"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["secretsmanager:GetSecretValue"],
        "Resource" : [aws_secretsmanager_secret.factorio_secret.id]
      }
    ]
  })
}

resource "aws_iam_role" "factorio_role" {
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

resource "aws_iam_role_policy_attachment" "factorio_attach" {
  role       = aws_iam_role.factorio_role.name
  policy_arn = aws_iam_policy.factorio_policy.arn
}

resource "aws_iam_instance_profile" "factorio_profile" {
  name = "factorio_profile"
  role = aws_iam_role.factorio_role.name
}

resource "aws_key_pair" "mmazzanti" {
  key_name   = "mmazzanti"
  public_key = file("${path.module}/keys/mmazzanti.pub")
}

resource "aws_instance" "factorio" {
  ami           = "ami-07df5833f04703a2a"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mmazzanti.key_name

  user_data            = file("${path.module}/configuration.nix")
  iam_instance_profile = aws_iam_instance_profile.factorio_profile.name

  tags = {
    Name = "factorio"
  }
}

output "factorio_ip_addr" {
  value = aws_instance.factorio.public_ip
}
