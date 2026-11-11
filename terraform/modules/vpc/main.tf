resource "aws_vpc" "main_rahul" {
  cidr_block           = var.vpc_cidr_rahul
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name_rahul}-${var.environment_rahul}-vpc"
    Environment = var.environment_rahul
    Owner       = "Rahul"
  }
}

resource "aws_internet_gateway" "main_rahul" {
  vpc_id = aws_vpc.main_rahul.id

  tags = {
    Name = "${var.project_name_rahul}-${var.environment_rahul}-igw"
  }
}

resource "aws_subnet" "public_rahul" {
  count = length(var.public_subnet_cidrs_rahul)

  vpc_id                  = aws_vpc.main_rahul.id
  cidr_block              = var.public_subnet_cidrs_rahul[count.index]
  availability_zone       = var.availability_zones_rahul[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                                       = "${var.project_name_rahul}-${var.environment_rahul}-public-${count.index + 1}"
    Tier                                                                       = "Public"
    "kubernetes.io/role/elb"                                                   = "1"
    "kubernetes.io/cluster/${var.project_name_rahul}-${var.environment_rahul}" = "shared"
  }
}

resource "aws_subnet" "private_rahul" {
  count = length(var.private_subnet_cidrs_rahul)

  vpc_id            = aws_vpc.main_rahul.id
  cidr_block        = var.private_subnet_cidrs_rahul[count.index]
  availability_zone = var.availability_zones_rahul[count.index]

  tags = {
    Name                                                                       = "${var.project_name_rahul}-${var.environment_rahul}-private-${count.index + 1}"
    Tier                                                                       = "Private"
    "kubernetes.io/role/internal-elb"                                          = "1"
    "kubernetes.io/cluster/${var.project_name_rahul}-${var.environment_rahul}" = "shared"
  }
}

resource "aws_route_table" "public_rahul" {
  vpc_id = aws_vpc.main_rahul.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_rahul.id
  }

  tags = {
    Name = "${var.project_name_rahul}-${var.environment_rahul}-public-rt"
  }
}

resource "aws_route_table_association" "public_rahul" {
  count = length(aws_subnet.public_rahul)

  subnet_id      = aws_subnet.public_rahul[count.index].id
  route_table_id = aws_route_table.public_rahul.id
}

resource "aws_eip" "nat_rahul" {
  count  = var.enable_nat_gateway_rahul ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name_rahul}-${var.environment_rahul}-nat-eip"
  }
}

resource "aws_nat_gateway" "main_rahul" {
  count         = var.enable_nat_gateway_rahul ? 1 : 0
  allocation_id = aws_eip.nat_rahul[0].id
  subnet_id     = aws_subnet.public_rahul[0].id

  depends_on = [aws_internet_gateway.main_rahul]

  tags = {
    Name = "${var.project_name_rahul}-${var.environment_rahul}-nat"
  }
}

resource "aws_route_table" "private_rahul" {
  count  = length(aws_subnet.private_rahul)
  vpc_id = aws_vpc.main_rahul.id

  tags = {
    Name = "${var.project_name_rahul}-${var.environment_rahul}-private-rt-${count.index + 1}"
  }
}

resource "aws_route" "private_nat_rahul" {
  count                  = var.enable_nat_gateway_rahul ? length(aws_route_table.private_rahul) : 0
  route_table_id         = aws_route_table.private_rahul[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main_rahul[0].id
}

resource "aws_route_table_association" "private_rahul" {
  count = length(aws_subnet.private_rahul)

  subnet_id      = aws_subnet.private_rahul[count.index].id
  route_table_id = aws_route_table.private_rahul[count.index].id
}
