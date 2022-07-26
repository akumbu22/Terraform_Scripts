provider "aws" {
  region     = "us-east-1"
}

resource "aws_instance" "ec2instance" {
  tags = {
    Name = "instance with role by Terraform"
  }
  ami             = "ami-06640050dc3f556bb"
  instance_type   = "t2.micro"
  key_name        = "ademola"
  security_groups = ["launch-wizard-30"]
}

