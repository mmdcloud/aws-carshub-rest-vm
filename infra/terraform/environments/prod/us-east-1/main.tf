# -----------------------------------------------------------------------------------------
# Shared Data Sources & Providers
# -----------------------------------------------------------------------------------------
data "vault_generic_secret" "rds" {
  path = "secret/rds"
}

data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "main" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_id" "id" {
  byte_length = 8
}
