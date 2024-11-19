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
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

resource "aws_vpc" "jieun_terraform" {
  cidr_block           = var.address_space
  enable_dns_hostnames = true

  tags = {
    name = "jieun-terraform-vpc"
  }
}

data "aws_network_acls" "jieun_terraform" {
  vpc_id = aws_vpc.jieun_terraform.id

  filter {
    name   = "default"
    values = ["true"]
  }
}

resource "aws_network_acl_rule" "deny80" {
  network_acl_id = data.aws_network_acls.jieun_terraform.ids[0]
  rule_number    = 80
  egress         = true
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "100.20.70.12/32"
}

resource "aws_network_acl_rule" "deny81" {
  network_acl_id = data.aws_network_acls.jieun_terraform.ids[0]
  rule_number    = 81
  egress         = true
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "35.166.5.222/32"
}

resource "aws_network_acl_rule" "deny82" {
  network_acl_id = data.aws_network_acls.jieun_terraform.ids[0]
  rule_number    = 82
  egress         = true
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "23.95.85.111/32"
}

resource "aws_network_acl_rule" "deny83" {
  network_acl_id = data.aws_network_acls.jieun_terraform.ids[0]
  rule_number    = 83
  egress         = true
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "44.215.244.1/32"
}

resource "aws_subnet" "multi_az" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.jieun_terraform.id
  cidr_block        = "${var.vpc_cidr_base}.${count.index}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "subnet-${var.availability_zones[count.index]}"
  }
}

resource "aws_security_group" "jieun_terraform" {
  name   = "${var.prefix}-security-group"
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

  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8201
    to_port     = 8201
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

resource "aws_route_table_association" "jieun_terraform" {
  count = length(aws_subnet.multi_az)

  route_table_id = aws_route_table.jieun_terraform.id
  subnet_id      = aws_subnet.multi_az[count.index].id
}

data "aws_ami" "al2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Canonical
}

resource "aws_instance" "web" {
  count                       = length(aws_subnet.multi_az)
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.multi_az[count.index].id
  key_name                    = "jieun"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jieun_terraform.id]
  iam_instance_profile        = aws_iam_instance_profile.terraform_profile.name

  tags = {
    Name    = "jieun-terraform-${count.index}"
    Service = "vault"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y yum-utils
              sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
              sudo yum -y install vault-enterprise

              export INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
              cat > /etc/vault.d/vault.hcl <<EOV
              ui = true
              disable_mlock = true

              cluster_addr  = "http://{{ GetInterfaceIP \"ens5\" }}:8201"
              api_addr        = "http://{{ GetInterfaceIP \"ens5\" }}:8200"

              storage "raft" {
                path = "/opt/vault/data"
                node_id = "$INSTANCE_ID"
                retry_join {
                    auto_join = "provider=aws addr_type=public_v4 region=${var.region} tag_key=Service tag_value=vault"
                    auto_join_scheme = "http"
                }
              }

              listener "tcp" {
                address = "0.0.0.0:8200"
                tls_disable = 1
              }

              license_path = "/etc/vault.d/vault.hclic"

              # Example AWS KMS auto unseal
              seal "awskms" {
                region = "${var.region}"
                kms_key_id = "${aws_kms_key.terraform_kms_key.key_id}"
              }

              reporting {
                license {
                  enabled = false
                }
              }
              EOV

              cat > /etc/vault.d/vault.hclic <<EOL
              ${var.vault_license}
              EOL

              sudo systemctl enable vault
              sudo systemctl start vault
              EOF
}

resource "aws_iam_role" "vault_role" {
  name = "jieun_terraform_vault_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    tag-key = "jieun-terraform-vault"
  }
}

resource "aws_iam_policy" "ec2policy" {
  name        = "jieun_terraform_vault_policy"
  path        = "/"
  description = "My vault autojoin policy using terraform"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Statement1",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "kmspolicy" {
  name        = "jieun_terraform_vault_kms_policy"
  path        = "/"
  description = "My vault autounseal policy using terraform"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Statement1",
        "Effect" : "Allow",
        "Action" : [
          "kms:DescribeKey",
          "kms:Decrypt",
          "kms:Encrypt"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "autojoin_policy_attachment" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.ec2policy.arn
}

resource "aws_iam_role_policy_attachment" "autounseal_policy_attachment" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.kmspolicy.arn
}

resource "aws_iam_instance_profile" "terraform_profile" {
  name = "jieun_terraform_profile"
  role = aws_iam_role.vault_role.name

  lifecycle {
    prevent_destroy = false # 삭제 가능하도록 설정
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "terraform_kms_key" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "jieun-terraform-key"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}
