provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA4GBFUK4ZAJPXJESO"
  secret_key = "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"
}

resource "aws_instance" "ec2instance" {
  tags = {
    Name = "first by Terraform"
  }
  ami             = "ami-06640050dc3f556bb"
  instance_type   = "t2.micro"
  key_name        = "ademola"
  security_groups = ["launch-wizard-30"]
}

