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

resource "aws_instance" "factorio" {
  ami           = "ami-07df5833f04703a2a"
  instance_type = "t2.micro"
  key_name      = "mmazzanti"

  tags = {
    Name = "factorio"
  }
}
