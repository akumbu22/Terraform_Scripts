provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA4GBFUK4ZAJPXJESO"
  secret_key = "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"
}

resource "aws_instance" "ec2instance" {
  tags = {
    Name = "variable instance by Terraform"
  }
  ami             = "${var.ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "ademola"
  security_groups = ["launch-wizard-30"]
}

