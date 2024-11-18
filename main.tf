terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-3"
}

resource "aws_vpc" "jieun_terraform" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "${var.prefix}-vpc-${var.region}"
    environment = "Production"
  }
}

# resource "aws_subnet" "jieun-terraform" {
#   vpc_id     = aws_vpc.jieun-terraform.id
#   cidr_block = var.subnet_prefix

#   tags = {
#     name = "${var.prefix}-subnet"
#   }
# }

resource "aws_subnet" "jieun_terraform" {
  for_each = var.subnets

  vpc_id     = aws_vpc.jieun_terraform.id
  cidr_block = each.value

  tags = {
    Name = "${var.prefix}-${each.key}"
  }
}

resource "aws_security_group" "jieun_terraform" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.jieun_terraform.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource "aws_internet_gateway" "jieun_terraform" {
  vpc_id = aws_vpc.jieun_terraform.id

  tags = {
    Name = "${var.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "jieun_terraform" {
  vpc_id = aws_vpc.jieun_terraform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jieun_terraform.id
  }
}

# resource "aws_route_table_association" "jieun_terraform" {
#   subnet_id      = aws_subnet.jieun_terraform.id
#   route_table_id = aws_route_table.jieun_terraform.id
# }

resource "aws_route_table_association" "jieun_terraform" {
  for_each = aws_subnet.jieun_terraform

  route_table_id = aws_route_table.jieun_terraform.id
  subnet_id      = each.value.id
}