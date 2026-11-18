variable "aws_region" {                           # Input value: which AWS region to work in
  type        = string                            # The value must be text
  description = "region used to deploy workloads" # Documentation shown to anyone using this variable
  default     = "us-east-1"                       # Used if no other value is provided

  validation {                                                                                       # A rule that checks the value before Terraform runs
    condition     = can(regex("^us-", var.aws_region))                                               # The value must start with "us-"
    error_message = "The aws_region value must be a valid region in the USA, starting with \"us-\"." # Shown if the rule fails
  }
}

variable "vpc_name" {  # Input value: the name tag for the VPC
  type    = string     # The value must be text
  default = "demo_vpc" # Used if no other value is provided
}

variable "vpc_cidr" {     # Input value: the IP address range of the VPC
  type    = string        # The value must be text
  default = "10.0.0.0/16" # A /16 range = 65,536 private IP addresses
}

# -------------------------------------------------------------------
# Task 3 (final): variables WITH default values
# Task 2 version: delete the "default" lines and Terraform will ask
# you for each value interactively when you run terraform plan
# -------------------------------------------------------------------
variable "variables_sub_cidr" {                       # Input value: IP range for the variables subnet
  description = "CIDR Block for the Variables Subnet" # Documentation shown to anyone using this variable
  type        = string                                # The value must be text
  default     = "10.0.202.0/24"                       # Used if no other value is provided (Task 2 used 10.0.250.0/24)
}

variable "variables_sub_az" {                                 # Input value: which AZ the variables subnet goes into
  description = "Availability Zone used for Variables Subnet" # Documentation shown to anyone using this variable
  type        = string                                        # The value must be text
  default     = "us-east-1a"                                  # Used if no other value is provided
}

variable "variables_sub_auto_ip" {                                 # Input value: should the subnet auto-assign public IPs?
  description = "Set Automatic IP Assignment for Variables Subnet" # Documentation shown to anyone using this variable
  type        = bool                                               # The value must be true or false
  default     = true                                               # Used if no other value is provided
}
