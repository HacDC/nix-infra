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
