# =============================================================================
# Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ansible-demo"
}

variable "environment" {
  description = "Environment name (dev, stg, prod)"
  type        = string
  default     = "dev"
}

# =============================================================================
# Network
# =============================================================================

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# =============================================================================
# EC2
# =============================================================================

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for Ansible"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # 本番では制限すること
}

variable "web_instance_count" {
  description = "Number of web server instances"
  type        = number
  default     = 2
}

variable "web_instance_type" {
  description = "Web server instance type"
  type        = string
  default     = "t3.small"
}

variable "app_instance_count" {
  description = "Number of app server instances"
  type        = number
  default     = 2
}

variable "app_instance_type" {
  description = "App server instance type"
  type        = string
  default     = "t3.medium"
}
