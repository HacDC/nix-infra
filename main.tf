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
  aws_region = data.aws_region.current.name
  # TODO: hack
  aws_az = "${data.aws_region.current.name}b"
}

variable "dns_zone_id" {
  description = "Route 53 zone ID"
  type        = string
}

variable "ssh_public_key" {
  description = "Local ssh key"
  type        = string
  sensitive   = true
}

variable "deployer_ip" {
  type = string
}


# Create deploy key
resource "aws_key_pair" "deploy_key" {
  key_name   = "deploy_key"
  public_key = var.ssh_public_key
}

locals {
  user_data = file("${path.module}/cfg/base.nix")
}

# ===== Factorio =====
variable "factorio_password" {
  description = "In-game factorio password"
  type        = string
  sensitive   = true
}

variable "factorio_player_ips" {
  type = map(string)
}

module "factorio" {
  source      = "./instances/factorio"
  aws_az      = local.aws_az
  dns_zone_id = var.dns_zone_id
  key_name    = aws_key_pair.deploy_key.key_name
  deployer_ip = var.deployer_ip
  password    = var.factorio_password
  player_ips  = var.factorio_player_ips
  user_data   = local.user_data
}

output "factorio_ip" {
  value = module.factorio.ip
}


# ===== Terraria =====
variable "terraria_password" {
  description = "In-game terraria password"
  type        = string
  sensitive   = true
}

variable "terraria_player_ips" {
  type = map(string)
}

module "terraria" {
  source      = "./instances/terraria"
  aws_az      = local.aws_az
  dns_zone_id = var.dns_zone_id
  key_name    = aws_key_pair.deploy_key.key_name
  deployer_ip = var.deployer_ip
  password    = var.terraria_password
  player_ips  = var.terraria_player_ips
  user_data   = local.user_data
}

output "terraria_ip" {
  value = module.terraria.ip
}
