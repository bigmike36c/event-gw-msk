terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.4.0"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# ------------------------
# Networking
# ------------------------

# Get availability zones for the region
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_3" {
  subnet_id      = aws_subnet.public_3.id
  route_table_id = aws_route_table.public.id
}


# ------------------------
# Security Groups
# ------------------------
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  # Allow SSH from anywhere (now that we have proper key-based auth)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "msk_sg" {
  vpc_id = aws_vpc.main.id

  # Allow SASL/SCRAM (port 9094)
  ingress {
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  # Allow SASL/SCRAM + TLS (port 9096)
  ingress {
    from_port       = 9096
    to_port         = 9096
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------
# SSH Key Pair
# ------------------------
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.instance_name}-ssh-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save the private key to a local file
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "ssh_key.pem"
  file_permission = "0600"
}

# ------------------------
# EC2 instance
# ------------------------
resource "aws_instance" "ec2" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.ssh_key.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Install kafkactl
    curl -L "https://github.com/deviceinsight/kafkactl/releases/download/v5.12.1/kafkactl_5.12.1_linux_amd64.tar.gz" -o /tmp/kafkactl.tar.gz
    tar -xzf /tmp/kafkactl.tar.gz -C /tmp
    mv /tmp/kafkactl /usr/local/bin/kafkactl
    chmod +x /usr/local/bin/kafkactl
    ln -s /usr/local/bin/kafkactl /usr/bin/kafkactl
    
    # Clean up
    rm /tmp/kafkactl.tar.gz
    
    # Install Git
    yum install -y git
    
    # Clone repository with sparse checkout for knep-deployment
    git clone --no-checkout https://github.com/bigmike36c/event-gw-msk.git /home/ec2-user/event-gw-msk
    cd /home/ec2-user/event-gw-msk
    
    # Enable sparse checkout and set specific directory
    git sparse-checkout init --cone
    git sparse-checkout set knep-deployment/
    
    # Checkout only the specified directory 
    git checkout
    
    # Change ownership
    chown -R ec2-user:ec2-user /home/ec2-user/knep-config
  EOF

  tags = {
    Name = var.instance_name
  }
}

# ------------------------
# MSK Cluster (TLS + SCRAM) - Simple 2-subnet setup
# ------------------------
resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3 # Back to 3 for proper quorum

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = [aws_subnet.public.id, aws_subnet.public_2.id, aws_subnet.public_3.id] # All 3 subnets
    security_groups = [aws_security_group.msk_sg.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      scram = true
    }
  }

  tags = {
    Name = "knep-msk"
  }
}

# ------------------------
# KMS Key for MSK SCRAM Secrets
# ------------------------
resource "aws_kms_key" "msk_scram" {
  description = "KMS key for MSK SCRAM secrets"

  tags = {
    Name = "knep-msk-scram-key"
  }
}

resource "aws_kms_alias" "msk_scram" {
  name          = "alias/knep-msk-scram"
  target_key_id = aws_kms_key.msk_scram.key_id
}

# ------------------------
# SCRAM Secret/User
# ------------------------
resource "aws_secretsmanager_secret" "scram" {
  name       = var.secret_name
  kms_key_id = aws_kms_key.msk_scram.arn
}

resource "aws_secretsmanager_secret_version" "scram_version" {
  secret_id = aws_secretsmanager_secret.scram.id
  secret_string = jsonencode({
    username = var.msk_username
    password = var.msk_password
  })
}

resource "aws_msk_scram_secret_association" "scram_assoc" {
  cluster_arn     = aws_msk_cluster.this.arn
  secret_arn_list = [aws_secretsmanager_secret.scram.arn]
}

# ------------------------
