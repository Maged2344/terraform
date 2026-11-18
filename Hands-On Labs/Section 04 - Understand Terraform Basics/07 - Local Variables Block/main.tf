# Configure the AWS Provider
provider "aws" {          # Tell Terraform that we want to build things in AWS
  region = var.aws_region # Region comes from the aws_region variable
}

#Define the VPC
resource "aws_vpc" "vpc" {  # Create the VPC - our own private network in the cloud
  cidr_block = var.vpc_cidr # The IP address range of the VPC, taken from the vpc_cidr variable

  tags = {              # Labels attached to the VPC
    Name = var.vpc_name # Human-friendly name, taken from the vpc_name variable
  }
}

#Deploy one public subnet (the lab's web server is launched inside it)
resource "aws_subnet" "public_subnets" {       # Creates one subnet per entry in the public_subnets variable
  for_each                = var.public_subnets # Loop over the map: one subnet for each key/value pair
  vpc_id                  = aws_vpc.vpc.id     # Place the subnet inside the VPC we created above
  cidr_block              = "10.0.101.0/24"    # The IP range of the subnet
  availability_zone       = "us-east-1a"       # The AZ the subnet lives in
  map_public_ip_on_launch = true               # Give every instance launched here a public IP automatically

  tags = {          # Labels attached to the subnet
    Name = each.key # Name the subnet after its key in the map (public_subnet_1)
  }
}

# Terraform Data Block - Lookup Ubuntu 20.04
data "aws_ami" "ubuntu" { # Search AWS for an existing Ubuntu 20.04 image (AMI)
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

# =====================================================================
# Task 1: Locals Block - named values defined right in the code.
# Locals are NOT set by the user and do NOT change during the workflow.
# The intro example from the lab also shows: time = timestamp()
# =====================================================================
locals {
  team        = "api_mgmt_dev"                                       # A simple value with a name
  application = "corp_api"                                           # Another simple value with a name
  server_name = "ec2-${var.environment}-api-${var.variables_sub_az}" # Build the name from two input variables
}

#Update the web server to use the LOCALS for its tags
resource "aws_instance" "web_server" {                            # Create a virtual server (EC2 instance)
  ami           = data.aws_ami.ubuntu.id                          # The OS image to boot from, found by the ubuntu data block above
  instance_type = "t3.micro"                                      # The hardware size of the server (small and free-tier friendly)
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id # Launch the server inside the subnet we created above

  tags = {                    # Labels attached to the server
    Name  = local.server_name # Comes from the locals block (note: local, NOT locals)
    Owner = local.team        # Comes from the locals block
    App   = local.application # Comes from the locals block
  }
}
