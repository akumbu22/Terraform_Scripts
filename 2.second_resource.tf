resource "aws_instance" "ec2instance" {
  tags = {
    Name = "Instance by Terraform- 2 files"
  }
  ami             = "ami-06640050dc3f556bb"
  instance_type   = "t2.micro"
  key_name        = "ademola"
  security_groups = ["launch-wizard-30"]
}
