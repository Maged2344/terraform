# Configure the AWS Provider
provider "aws" {       # Tell Terraform that we want to build things in AWS
  region = "us-east-2" # Build everything in the us-east-1 region

}




#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {} # Ask AWS for the list of availability zones (us-east-1a, 1b, 1c, ...)
data "aws_region" "current" {}               # Ask AWS which region we are currently working in

# Terraform Data Block - Lookup Ubuntu 20.04
data "aws_ami" "ubuntu" { # Search AWS for an existing Ubuntu 20.04 machine image (AMI) - data blocks only READ, they create nothing
  most_recent = true      # If several images match, use the newest one

  filter {
    name   = "name"                                                      # Search by image name...
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"] # ...matching this Ubuntu 20.04 pattern
  }

  filter {
    name   = "virtualization-type" # Also search by virtualization type...
    values = ["hvm"]               # ...only HVM images are allowed
  }

  owners = ["099720109477"] # Only accept images owned by Canonical, the official Ubuntu publisher
}


resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.variables-subnet.id
  tags = {
    Name = local.server_name
    Owner = local.team
    App = local.application
  }
}

action "aws_ec2_stop_instance" "stop_instance" {
  config {
    instance_id = aws_instance.web_server.id
  }
}


#Define the VPC
resource "aws_vpc" "vpc" {  # Create the VPC - our own private network in the cloud
  cidr_block = var.vpc_cidr # The IP address range of the VPC, taken from the vpc_cidr variable

  tags = {                           # Labels attached to the VPC
    Name        = var.vpc_name       # Human-friendly name, taken from the vpc_name variable
    Environment = var.vpc_env # Marks this as a demo environment
    Terraform   = var.vpc_terraform             # Marks this resource as managed by Terraform
  }
}

resource "aws_subnet" "variables-subnet" {          # One extra subnet built entirely from variables (practice for the variables lesson)
  vpc_id                  =  aws_vpc.vpc.id           # Place the subnet inside our VPC
  cidr_block              =  var.variables_sub_cidr                        # IP range taken from the variables_sub_cidr variable
  availability_zone       =  var.variables_sub_az                           # AZ taken from the variables_sub_az variable
  map_public_ip_on_launch =  var.variables_sub_auto_ip                    # Auto-assign public IPs, taken from the variables_sub_auto_ip variable

  tags = {                                              # Labels attached to the subnet
    Name      = "sub-variables-${var.variables_sub_az}" # Name includes the AZ, using ${} string interpolation
    Terraform = "true"                                  # Marks this resource as managed by Terraform
  }
}


locals {
  team = "api_mgmt_dev"
  application = "corp_api"
  server_name = "ec2-${var.vpc_env}-api-${var.variables_sub_az}"
}




