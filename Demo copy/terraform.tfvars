# Input value: IP range for the extra "variables" subnet
# This overrides the default (10.0.1.0/24) set in variables.tf
variables_sub_cidr = "10.0.100.0/24"
aws_region = "us-east-2"
vpc_name = "demo-vpc"
vpc_env = "production"
environment = "dev"