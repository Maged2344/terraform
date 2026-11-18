# Configure the AWS Provider
provider "aws" {          # Tell Terraform that we want to build things in AWS
  region = var.aws_region # Region comes from the aws_region variable
}

# =====================================================================
# Task 1: query the current AWS region with a data source
# =====================================================================
#Retrieve the AWS region
data "aws_region" "current" {} # Asks AWS which region we are working in (us-east-1)

# =====================================================================
# Task 3: this data source was already used - it reads the AZ list
# =====================================================================
#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {} # Asks AWS for the list of AZs (us-east-1a, 1b, 1c, ...) - same code works in ANY region

# =====================================================================
# Task 5: query a different Ubuntu image (22.04 this time)
# =====================================================================
# Terraform Data Block - Lookup Ubuntu 22.04
data "aws_ami" "ubuntu_22_04" { # Search AWS for an existing Ubuntu 22.04 image (AMI)
  most_recent = true            # If several images match, use the newest one

  filter {
    name   = "name"                                                      # Search by image name...
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"] # ...matching this Ubuntu 22.04 pattern
  }

  owners = ["099720109477"] # Only accept images owned by Canonical, the official Ubuntu publisher
}

# =====================================================================
# Task 2: the VPC now uses the region data source in a tag
# Reference pattern: data.<type>.<name>.<attribute>
# =====================================================================
#Define the VPC
resource "aws_vpc" "vpc" {  # Create the VPC - our own private network in the cloud
  cidr_block = var.vpc_cidr # The IP address range of the VPC, taken from the vpc_cidr variable

  tags = {                                     # Labels attached to the VPC
    Name        = var.vpc_name                 # Human-friendly name, taken from the vpc_name variable
    Environment = "demo_environment"           # Marks this as a demo environment
    Terraform   = "true"                       # Marks this resource as managed by Terraform
    Region      = data.aws_region.current.name # The region, read by the data block above (type=aws_region, name=current, attribute=name)
  }
}

# =====================================================================
# Task 4: the subnets already use the AZ data source dynamically
# =====================================================================
#Deploy the private subnets
resource "aws_subnet" "private_subnets" {                                                       # Create one subnet per entry in the private_subnets variable
  for_each                = var.private_subnets                                                 # Loop over the map: one subnet for each key/value pair
  vpc_id                  = aws_vpc.vpc.id                                                      # Place the subnet inside the VPC we created above
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)                             # Carve a /24 slice (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24) out of the VPC range
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value - 1] # The AZ comes from the data source: subnet 1 -> us-east-1a, subnet 2 -> us-east-1b, ...
  map_public_ip_on_launch = true                                                                # Normally private subnets don't do this, but our web server needs a public IP

  tags = {               # Labels attached to each subnet
    Name      = each.key # Name the subnet after its key in the map (private_subnet_1, ...)
    Terraform = "true"   # Marks this resource as managed by Terraform
  }
}

# =====================================================================
# Task 6: the web server now uses the Ubuntu 22.04 AMI from the data block
# Note: the lab PDF also had security_groups = [aws_security_group.vpc-ping.id],
# but that security group is not part of this lab, so it is left out
# (the VPC default security group is used instead).
# =====================================================================
resource "aws_instance" "web_server" {                                            # Create a virtual server (EC2 instance)
  ami                         = data.aws_ami.ubuntu_22_04.id                      # The OS image, found by the ubuntu_22_04 data block above
  instance_type               = "t3.micro"                                        # The hardware size of the server (small and free-tier friendly)
  subnet_id                   = aws_subnet.private_subnets["private_subnet_1"].id # Launch the server inside the first subnet we created above
  associate_public_ip_address = true                                              # Give the server a public IP address

  tags = {                  # Labels attached to the server
    Name = "Web EC2 Server" # Human-friendly name
  }
}
