variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for the database server"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of the existing EC2 Key Pair for SSH access (optional)"
  type        = string
  default     = ""
}

variable "my_ip_address" {
  description = "Your current public IP address in CIDR notation (e.g. 102.89.23.1/32) — used to restrict Bastion SSH access"
  type        = string
}

variable "bastion_password" {
  description = "Password for ec2-user on the Bastion, Web, and DB servers (used for username/password SSH access)"
  type        = string
  sensitive   = true
}
