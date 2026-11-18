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

#Define the VPC
resource "aws_vpc" "vpc" {  # Create the VPC - our own private network in the cloud
  cidr_block = var.vpc_cidr # The IP address range of the VPC, taken from the vpc_cidr variable

  tags = {                           # Labels attached to the VPC
    Name        = var.vpc_name       # Human-friendly name, taken from the vpc_name variable
    Environment = "demo_environment" # Marks this as a demo environment
    Terraform   = "true"             # Marks this resource as managed by Terraform
  }
}

#Deploy the private subnets
resource "aws_subnet" "private_subnets" {                                                 # Create one private subnet per entry in the private_subnets variable (for_each = a loop)
  for_each          = var.private_subnets                                                 # Loop over the map: one subnet for each key/value pair
  vpc_id            = aws_vpc.vpc.id                                                      # Place the subnet inside the VPC we created above
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)                             # Carve a /24 slice (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24) out of the VPC range
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value - 1] # Put subnet 1 in AZ 1 (us-east-1a), subnet 2 in AZ 2 (us-east-1b), and so on

  tags = {               # Labels attached to each subnet
    Terraform = "true"   # Marks this resource as managed by Terraform
  }
}

#Deploy the public subnets
resource "aws_subnet" "public_subnets" {                                                        # Create one public subnet per entry in the public_subnets variable
  for_each                = var.public_subnets                                                  # Loop over the map: one subnet for each key/value pair
  vpc_id                  = aws_vpc.vpc.id                                                      # Place the subnet inside the VPC we created above
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)                       # Carve a /24 slice starting at 100 (10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value - 1] # Put subnet 1 in AZ 1 (us-east-1a), subnet 2 in AZ 2 (us-east-1b), and so on
  map_public_ip_on_launch = true                                                                # Give every instance launched here a public IP address automatically

  tags = {               # Labels attached to each subnet
    Name      = each.key # Name the subnet after its key in the map (public_subnet_1, ...)
    Terraform = "true"   # Marks this resource as managed by Terraform
  }
}

#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" { # Routing rules for the public subnets
  vpc_id = aws_vpc.vpc.id                         # The route table belongs to our VPC

  route {                                                 # A single routing rule
    cidr_block = "0.0.0.0/0"                              # Match ALL traffic (every IP address on the internet)
    gateway_id = aws_internet_gateway.internet_gateway.id # Send that traffic out through the internet gateway
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id    # (Commented out) alternative: send traffic through the NAT gateway instead
  }
  tags = {                        # Labels attached to the route table
    Name      = "demo_public_rtb" # Human-friendly name
    Terraform = "true"            # Marks this resource as managed by Terraform
  }
}

resource "aws_route_table" "private_route_table" { # Routing rules for the private subnets
  vpc_id = aws_vpc.vpc.id                          # The route table belongs to our VPC

  route {                    # A single routing rule
    cidr_block = "0.0.0.0/0" # Match ALL traffic (every IP address on the internet)
    # gateway_id     = aws_internet_gateway.internet_gateway.id  # (Commented out) private subnets must NOT talk to the internet directly
    nat_gateway_id = aws_nat_gateway.nat_gateway.id # Send outbound traffic through the NAT gateway instead (out only, nobody can get in)
  }
  tags = {                         # Labels attached to the route table
    Name      = "demo_private_rtb" # Human-friendly name
    Terraform = "true"             # Marks this resource as managed by Terraform
  }
}

#Create route table associations
resource "aws_route_table_association" "public" {        # Attach the public route table to each public subnet
  depends_on     = [aws_subnet.public_subnets]           # Wait until the public subnets exist first
  route_table_id = aws_route_table.public_route_table.id # The route table to attach
  for_each       = aws_subnet.public_subnets             # Loop over every public subnet created above
  subnet_id      = each.value.id                         # The subnet being attached, one per loop iteration
}

resource "aws_route_table_association" "private" {        # Attach the private route table to each private subnet
  depends_on     = [aws_subnet.private_subnets]           # Wait until the private subnets exist first
  route_table_id = aws_route_table.private_route_table.id # The route table to attach
  for_each       = aws_subnet.private_subnets             # Loop over every private subnet created above
  subnet_id      = each.value.id                          # The subnet being attached, one per loop iteration
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" { # The door between our VPC and the public internet
  vpc_id = aws_vpc.vpc.id                            # Attach the gateway to our VPC
  tags = {                                           # Labels attached to the gateway
    Name = "demo_igw"                                # Human-friendly name
  }
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {                 # Reserve a static public IP address that never changes
  domain     = "vpc"                                   # The IP is for use inside a VPC (by the NAT gateway)
  depends_on = [aws_internet_gateway.internet_gateway] # Wait until the internet gateway exists first
  tags = {                                             # Labels attached to the IP
    Name = "demo_igw_eip"                              # Human-friendly name
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {                        # Lets private subnets reach the internet WITHOUT being reachable from it
  depends_on    = [aws_subnet.public_subnets]                     # Wait until the public subnets exist first
  allocation_id = aws_eip.nat_gateway_eip.id                      # Use the static public IP reserved above
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id # A NAT gateway must live in a PUBLIC subnet (we pick the first one)
  tags = {                                                        # Labels attached to the gateway
    Name = "demo_nat_gateway"                                     # Human-friendly name
  }
}

# Terraform Resource Block - To Build EC2 instance in Public Subnet
resource "aws_instance" "web_server" {                            # Create a virtual server (EC2 instance)
  ami           = data.aws_ami.ubuntu.id                          # The OS image to boot from, found by the ubuntu data block above
  instance_type = "t3.micro"                                      # The hardware size of the server (small and free-tier friendly)
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id # Launch the server inside the first public subnet
  tags = {                                                        # Labels attached to the server
    Name = "Web EC2 Server"                                       # Human-friendly name
  }
}

resource "aws_subnet" "variables-subnet" {            # One extra subnet built entirely from variables (practice for the variables lesson)
  vpc_id                  = aws_vpc.vpc.id            # Place the subnet inside our VPC
  cidr_block              = var.variables_sub_cidr    # IP range taken from the variables_sub_cidr variable
  availability_zone       = var.variables_sub_az      # AZ taken from the variables_sub_az variable
  map_public_ip_on_launch = var.variables_sub_auto_ip # Auto-assign public IPs, taken from the variables_sub_auto_ip variable

  tags = {                                              # Labels attached to the subnet
    Name      = "sub-variables-${var.variables_sub_az}" # Name includes the AZ, using ${} string interpolation
    Terraform = "true"                                  # Marks this resource as managed by Terraform
  }
}
