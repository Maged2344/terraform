variable "aws_region" { # Input value: which AWS region to work in
  type    = string      # The value must be text
  default = "us-east-2" # Used if no other value is provided
}

variable "vpc_name" {  # Input value: the name tag for the VPC
  type    = string     # The value must be text
  default = "demo_vpc" # Used if no other value is provided
}

variable "vpc_cidr" {     # Input value: the IP address range of the VPC
  type    = string        # The value must be text
  default = "10.0.0.0/16" # A /16 range = 65,536 private IP addresses to slice into subnets
}

variable "private_subnets" { # Input value: map of private subnets to create
  default = {                # A map: subnet name = subnet number
    "private_subnet_1" = 1   # First private subnet  -> number 1 -> 10.0.1.0/24 -> us-east-1a
    "private_subnet_2" = 2   # Second private subnet -> number 2 -> 10.0.2.0/24 -> us-east-1b
    "private_subnet_3" = 3   # Third private subnet  -> number 3 -> 10.0.3.0/24 -> us-east-1c
  }
}

variable "public_subnets" { # Input value: map of public subnets to create
  default = {               # A map: subnet name = subnet number
    "public_subnet_1" = 1   # First public subnet  -> number 1 -> 10.0.101.0/24 -> us-east-1a
    "public_subnet_2" = 2   # Second public subnet -> number 2 -> 10.0.102.0/24 -> us-east-1b
    "public_subnet_3" = 3   # Third public subnet  -> number 3 -> 10.0.103.0/24 -> us-east-1c
  }
}

variable "variables_sub_cidr" {                       # Input value: IP range for the extra "variables" subnet
  description = "CIDR Block for the Variables Subnet" # Documentation shown to anyone using this variable
  type        = string                                # The value must be text
  default     = "10.0.202.0/24"                       # Used if no other value is provided
}

variable "variables_sub_az" {                                 # Input value: which AZ the extra subnet goes into
  description = "Availability Zone used for Variables Subnet" # Documentation shown to anyone using this variable
  type        = string                                        # The value must be text
  default     = "us-east-1a"                                  # Used if no other value is provided
}

variable "variables_sub_auto_ip" {                                 # Input value: should the extra subnet auto-assign public IPs?
  description = "Set Automatic IP Assignment for Variables Subnet" # Documentation shown to anyone using this variable
  type        = bool                                               # The value must be true or false
  default     = true                                               # Used if no other value is provided
}
