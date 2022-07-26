variable "ami" {
    description = "Amazon Machine Image"
    default = "ami-06640050dc3f556bb"
}

variable "instance_type" {
    description = "Instance type, for example t2.medium, t2.micro, ..."
    default = "t2.micro"
}
