terraform {
  required_version = "~> 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

// vpc
resource "aws_vpc" "main" {
  cidr_block = "172.17.0.0/16"
}

locals {
  public_subnets = [
    {
      name       = "ap-northeast-1a",
      cidr_block = "172.17.1.0/24"
    },
    {
      name       = "ap-northeast-1c",
      cidr_block = "172.17.2.0/24"
    },
  ]
}

# public subnets
resource "aws_subnet" "public" {
  for_each = { for i in local.public_subnets : i.name => i }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.name
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  for_each = { for i in local.public_subnets : i.name => i }

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route" "public" {
  for_each = { for i in local.public_subnets : i.name => i }

  route_table_id         = aws_route_table.public[each.value.name].id
  gateway_id             = aws_internet_gateway.gw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public" {
  for_each = { for i in local.public_subnets : i.name => i }

  subnet_id      = aws_subnet.public[each.value.name].id
  route_table_id = aws_route_table.public[each.value.name].id
}

// private subnets
locals {
  private_subnets = [
    {
      name       = "ap-northeast-1a",
      cidr_block = "172.17.3.0/24"
    },
    {
      name       = "ap-northeast-1c",
      cidr_block = "172.17.4.0/24"
    },
  ]
}
resource "aws_subnet" "private" {
  for_each = { for i in local.private_subnets : i.name => i }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.name
  map_public_ip_on_launch = false
}

resource "aws_eip" "nat_gateway" {
  for_each = { for i in local.public_subnets : i.name => i }

  domain = "vpc"
  # https://www.terraform.io/docs/providers/aws/r/eip.html
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "nat_gateway" {
  for_each = { for i in local.public_subnets : i.name => i }

  allocation_id = aws_eip.nat_gateway[each.value.name].id
  subnet_id     = aws_subnet.public[each.value.name].id

  # https://www.terraform.io/docs/providers/aws/r/nat_gateway.html#argument-reference
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private" {
  for_each = { for i in local.private_subnets : i.name => i }

  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private" {
  for_each = { for i in local.public_subnets : i.name => i }

  route_table_id         = aws_route_table.private[each.value.name].id
  nat_gateway_id         = aws_nat_gateway.nat_gateway[each.value.name].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private" {
  for_each = { for i in local.private_subnets : i.name => i }

  subnet_id      = aws_subnet.private[each.value.name].id
  route_table_id = aws_route_table.private[each.value.name].id
}
