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

variable "public_subnets" { # Input value: map of public subnets to create
  default = {               # A map: subnet name = subnet number
    "public_subnet_1" = 1   # One public subnet -> 10.0.101.0/24 in us-east-1a
  }
}

variable "environment" { # Input value: used by the locals block to build the server name
  type    = string       # The value must be text
  default = "dev"        # Used if no other value is provided
}

variable "variables_sub_az" { # Input value: also used by the locals block to build the server name
  type    = string            # The value must be text
  default = "us-east-1a"      # Used if no other value is provided
}
