#----------------
# VPC
#----------------
resource "aws_vpc" "distribution_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "distribution-vpc"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#----------------
#Subnets
#----------------

# Public_a Subnet
resource "aws_subnet" "distribution_public_a" {
  vpc_id            = aws_vpc.distribution_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "distribution-public-a"
    environment = "development"
    managed_by  = "Terraform"
  }
}

# Private App_a Subnet
resource "aws_subnet" "distribution_private_app_a" {
  vpc_id            = aws_vpc.distribution_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "distribution-private-app-a"
    environment = "development"
    managed_by  = "Terraform"
  }
}

# Private DB_a Subnet
resource "aws_subnet" "distribution_private_db_a" {
  vpc_id            = aws_vpc.distribution_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "distribution-private-db-a"
    environment = "development"
    managed_by  = "Terraform"
  }
}

# Public_b Subnet
resource "aws_subnet" "distribution_public_b" {
  vpc_id            = aws_vpc.distribution_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "distribution-public-b"
    environment = "development"
    managed_by  = "Terraform"
  }
}

# Private App_b Subnet
resource "aws_subnet" "distribution_private_app_b" {
  vpc_id            = aws_vpc.distribution_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "distribution-private-app-b"
    environment = "development"
    managed_by  = "Terraform"
  }
}

# Private DB_b Subnet
resource "aws_subnet" "distribution_private_db_b" {
  vpc_id            = aws_vpc.distribution_vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "distribution-private-db-b"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#----------------------
# Internet Gateway
#----------------------

# Internet Gateway
resource "aws_internet_gateway" "distribution_igw" {
  vpc_id = aws_vpc.distribution_vpc.id

  tags = {
    Name        = "distribution-igw"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#----------------------
# Public Route Tables
#----------------------

# public_a Route Table
resource "aws_route_table" "distribution_public_rt_a" {
  vpc_id = aws_vpc.distribution_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.distribution_igw.id
  }

  tags = {
    Name = "distribution-public-rt-a"
  }
}

# public_b Route Table
resource "aws_route_table" "distribution_public_rt_b" {
  vpc_id = aws_vpc.distribution_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.distribution_igw.id
  }
  tags = {

    Name = "distribution-public-rt-b"
  }
}

#---------------------------------
# Public Route Table Associations
#---------------------------------

# public_a Route Table Association
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.distribution_public_a.id
  route_table_id = aws_route_table.distribution_public_rt_a.id
}

# public_b Route Table Association
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.distribution_public_b.id
  route_table_id = aws_route_table.distribution_public_rt_b.id
}

#-------------------------
# Elastic IP
#-------------------------

resource "aws_eip" "distribution_nat_eip_a" {
  domain = "vpc"

  tags = {
    Name = "distribution-nat-eip-a"
  }
}

#-------------------------
# NAT Gateway
#-------------------------

resource "aws_nat_gateway" "distribution_nat_a" {
  allocation_id = aws_eip.distribution_nat_eip_a.id
  subnet_id     = aws_subnet.distribution_public_a.id

  tags = {
    Name = "distribution-nat-a"
  }
  depends_on = [aws_internet_gateway.distribution_igw]
}

#-------------------------
# Private App Route Tables
#-------------------------

# private App_a Route Table
resource "aws_route_table" "distribution_private_app_rt_a" {
  vpc_id = aws_vpc.distribution_vpc.id

  tags = {
    Name = "distribution-private-app-rt-a"
  }
}

# private App_b Route Table
resource "aws_route_table" "distribution_private_app_rt_b" {
  vpc_id = aws_vpc.distribution_vpc.id

  tags = {
    Name = "distribution-private-app-rt-b"
  }
}

#-------------------------
# Private App Routes
#-------------------------

# Private App_a Route
resource "aws_route" "private_app_a_nat" {
  route_table_id         = aws_route_table.distribution_private_app_rt_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.distribution_nat_a.id
}

# Private App_b Route
resource "aws_route" "private_app_b_nat" {
  route_table_id         = aws_route_table.distribution_private_app_rt_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.distribution_nat_a.id
}

#------------------------------------
# Private App Route Table Associations
#-------------------------------------

# Private app_a Route Table Association
resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.distribution_private_app_a.id
  route_table_id = aws_route_table.distribution_private_app_rt_a.id
}

# Private app_b Route Table Association
resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.distribution_private_app_b.id
  route_table_id = aws_route_table.distribution_private_app_rt_b.id
}

#--------------------------
# Private DB Route Tables
#---------------------------

# private_db_a Route Table
resource "aws_route_table" "distribution_private_db_rt_a" {
  vpc_id = aws_vpc.distribution_vpc.id

  tags = {
    Name = "distribution-private-db-rt-a"
  }
}

# private_db_b Route Table
resource "aws_route_table" "distribution_private_db_rt_b" {
  vpc_id = aws_vpc.distribution_vpc.id

  tags = {
    Name = "distribution-private-db-rt-b"
  }
}

#-------------------------------------
# Private DB Route Tables Associations
#-------------------------------------

# Private db_a Route Table Association
resource "aws_route_table_association" "private_db_a" {
  subnet_id      = aws_subnet.distribution_private_db_a.id
  route_table_id = aws_route_table.distribution_private_db_rt_a.id
}

# Private db_b Route Table Association
resource "aws_route_table_association" "private_db_b" {
  subnet_id      = aws_subnet.distribution_private_db_b.id
  route_table_id = aws_route_table.distribution_private_db_rt_b.id
}

