# Configure the AWS Provider
provider "aws" {          # Tell Terraform that we want to build things in AWS
  region = var.aws_region # Region comes from the aws_region variable (with a validation rule)
}

#Define the VPC
resource "aws_vpc" "vpc" {  # Create the VPC - our own private network in the cloud
  cidr_block = var.vpc_cidr # The IP address range of the VPC, taken from the vpc_cidr variable

  tags = {              # Labels attached to the VPC
    Name = var.vpc_name # Human-friendly name, taken from the vpc_name variable
  }
}

# =====================================================================
# Task 1 (starting point): the subnet built with STATIC values
# Uncomment this block and comment the block below to show Task 1
# =====================================================================
# resource "aws_subnet" "variables-subnet" {
#   vpc_id                  = aws_vpc.vpc.id    # Place the subnet inside our VPC
#   cidr_block              = "10.0.250.0/24"   # The IP range is hard-coded
#   availability_zone       = "us-east-1a"      # The AZ is hard-coded
#   map_public_ip_on_launch = true              # Give instances a public IP automatically
#
#   tags = {
#     Name      = "sub-variables-us-east-1a"    # The name is hard-coded too
#     Terraform = "true"
#   }
# }

# =====================================================================
# Task 2 + 3 (final): the SAME subnet, but using VARIABLES instead
# =====================================================================
resource "aws_subnet" "variables-subnet" {            # Create the subnet inside the VPC
  vpc_id                  = aws_vpc.vpc.id            # Place the subnet inside the VPC we created above
  cidr_block              = var.variables_sub_cidr    # IP range taken from the variables_sub_cidr variable
  availability_zone       = var.variables_sub_az      # AZ taken from the variables_sub_az variable
  map_public_ip_on_launch = var.variables_sub_auto_ip # Auto-assign public IPs, taken from the variables_sub_auto_ip variable

  tags = {                                              # Labels attached to the subnet
    Name      = "sub-variables-${var.variables_sub_az}" # Name includes the AZ, using ${} string interpolation
    Terraform = "true"                                  # Marks this resource as managed by Terraform
  }
}
