# ============================================================
# PROVIDER
# ============================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.14.7"
}

provider "aws" {
  region = var.region
}

# ============================================================
# DATA SOURCES
# ============================================================

# Fetch the latest Amazon Linux 2 AMI automatically
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# VPC
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "techcorp-vpc"
  }
}

# ============================================================
# SUBNETS
# ============================================================

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Instances launched here get a public IP automatically
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "techcorp-private-subnet-${count.index + 1}"
  }
}

# ============================================================
# INTERNET GATEWAY
# ============================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-igw"
  }
}

# ============================================================
# ELASTIC IPs FOR NAT GATEWAYS
# ============================================================
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "techcorp-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# NAT GATEWAYS (one per public subnet)
# ============================================================
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "techcorp-nat-gw-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# ROUTE TABLES
# ============================================================

# Public route table — routes all internet traffic through IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "techcorp-public-rt"
  }
}

# Associate both public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables — one per AZ, each routes through its own NAT GW
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "techcorp-private-rt-${count.index + 1}"
  }
}

# Associate each private subnet with its corresponding private route table
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================
# SECURITY GROUPS
# ============================================================

# --- Bastion Security Group ---
resource "aws_security_group" "bastion" {
  name        = "techcorp-bastion-sg"
  description = "Allow SSH from admin IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-bastion-sg"
  }
}

# --- Web Security Group ---
resource "aws_security_group" "web" {
  name        = "techcorp-web-sg"
  description = "Allow HTTP, HTTPS from anywhere; SSH from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-web-sg"
  }
}

# --- Database Security Group ---
resource "aws_security_group" "database" {
  name        = "techcorp-db-sg"
  description = "Allow Postgres from web SG; SSH from bastion SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Web Security Group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-db-sg"
  }
}

# ============================================================
# EC2 — BASTION HOST
# ============================================================
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  # Enable username/password SSH login for ec2-user
  user_data = <<-EOF
    #!/bin/bash
    echo "ec2-user:${var.bastion_password}" | chpasswd
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name = "techcorp-bastion"
  }
}

# Elastic (public) IP for Bastion
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "techcorp-bastion-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# EC2 — WEB SERVERS
# ============================================================
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = base64encode(templatefile("${path.module}/user_data/web_server_setup.sh", {
    password = var.bastion_password
  }))

  tags = {
    Name = "techcorp-web-server-${count.index + 1}"
  }
}

# ============================================================
# EC2 — DATABASE SERVER
# ============================================================
resource "aws_instance" "database" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.database.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  user_data = base64encode(templatefile("${path.module}/user_data/db_server_setup.sh", {
    password = var.bastion_password
  }))

  tags = {
    Name = "techcorp-db-server"
  }
}

# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================
resource "aws_lb" "main" {
  name               = "techcorp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "techcorp-alb"
  }
}

# Target group pointing to web servers on port 80
resource "aws_lb_target_group" "web" {
  name     = "techcorp-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "techcorp-web-tg"
  }
}

# Register both web server instances in the target group
resource "aws_lb_target_group_attachment" "web" {
  count            = 2
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# ALB Listener on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
