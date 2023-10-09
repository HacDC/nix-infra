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

provider "aws" {
  region = "us-east-1"
}

provider "tailscale" {}

# Helpers to get the current caller id and region

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name
  # TODO: hack
  aws_az = "${data.aws_region.current.name}b"
}
