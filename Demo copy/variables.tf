variable "aws_region" { # Input value: which AWS region to work in
  type    = string      # The value must be text

}

variable "vpc_name" {  # Input value: the name tag for the VPC
  type    = string     # The value must be text

 
}

variable "vpc_env" {
  type = string
  default = "demo_environment"
}

variable "vpc_cidr" {     # Input value: the IP address range of the VPC
  type    = string        # The value must be text
  default = "10.0.0.0/16" # Used if no other value is provided

}

variable "vpc_terraform" {     # Input value: is this VPC managed by Terraform?
  type    = string         # The value must be true or false
  default = "true"         # Used if no other value is provided
}

variable "variables_sub_cidr" {                       # Input value: IP range for the extra "variables" subnet
  description = "CIDR Block for the Variables Subnet" # Documentation shown to anyone using this variable
  type        = string                                # The value must be text
  default     = "10.0.1.0/24"                       # Used if no other value is provided
}

variable "variables_sub_az" {                                 # Input value: which AZ the extra subnet goes into
  description = "Availability Zone used for Variables Subnet" # Documentation shown to anyone using this variable
  type        = string                                        # The value must be text
  default     = "us-east-2a"                                  # Used if no other value is provided
}

variable "variables_sub_auto_ip" {                                 # Input value: should the extra subnet auto-assign public IPs?
  description = "Set Automatic IP Assignment for Variables Subnet" # Documentation shown to anyone using this variable
  type        = bool                                               # The value must be true or false
  default     = true                                               # Used if no other value is provided
}

variable "environment" { # Input value: which environment are we building (dev, test, prod, etc.)
  type    = string      # The value must be text
}