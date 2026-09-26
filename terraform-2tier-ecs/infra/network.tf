# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-${var.prefix}-vpc"
  }
}

# create public subnet
resource "aws_subnet" "public_subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-${var.prefix}-public_subnet1"
  }
}


resource "aws_subnet" "public_subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.environment}-${var.prefix}-public_subnet2"
  }
}

# create private subnet
resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-${var.prefix}-private_subnet1"
  }
}


resource "aws_subnet" "private_subnet2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.environment}-${var.prefix}-private_subnet2"
  }
}

# Create rds subnet
resource "aws_subnet" "private_rds1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-${var.prefix}-private_rds1"
  }
}

resource "aws_subnet" "private_rds2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.environment}-${var.prefix}-private_rds2"
  }
}

# Create public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-${var.prefix}-public-route-table"
  }
}

# Private route table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-${var.prefix}-private_route_table"
  }
}

# Associate route table to subnet
# implicit dependency
resource "aws_route_table_association" "public_subnet1_association" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet1_association" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_subnet2_association" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet2_association" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-${var.prefix}-igw"
  }
  # explicit dependency
  depends_on = [aws_vpc.vpc]
}


# route to internet gateway
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# eip
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.environment}-${var.prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id

  tags = {
    Name = "${var.environment}-${var.prefix}-nat-gateway"
  }
}
# route to NAT Gateway
resource "aws_route" "private_subnet_1_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id

}