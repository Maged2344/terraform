variable "aws_region" { # Input value: which AWS region to work in
  type    = string      # The value must be text
  default = "us-east-1" # Used if no other value is provided
}

variable "vpc_name" {  # Input value: the name tag for the VPC
  type    = string     # The value must be text
  default = "demo_vpc" # Used if no other value is provided
}

variable "vpc_cidr" {     # Input value: the IP address range of the VPC
  type    = string        # The value must be text
  default = "10.0.0.0/16" # A /16 range = 65,536 private IP addresses
}

variable "private_subnets" { # Input value: map of private subnets to create
  default = {                # A map: subnet name = subnet number
    "private_subnet_1" = 1   # First private subnet  -> number 1 -> 10.0.1.0/24 -> us-east-1a
    "private_subnet_2" = 2   # Second private subnet -> number 2 -> 10.0.2.0/24 -> us-east-1b
    "private_subnet_3" = 3   # Third private subnet  -> number 3 -> 10.0.3.0/24 -> us-east-1c
  }
}
