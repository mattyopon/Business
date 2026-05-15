# =============================================================================
# Variables
# =============================================================================

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "search-system"
}

variable "environment" {
  description = "Environment (dev/stg/prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "Environment must be dev, stg, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# -----------------------------------------------------------------------------
# OpenSearch
# -----------------------------------------------------------------------------
variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.medium.search"
}

variable "opensearch_instance_count" {
  description = "OpenSearch instance count"
  type        = number
  default     = 2
}

variable "opensearch_volume_size" {
  description = "OpenSearch EBS volume size (GB)"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
variable "log_retention_days" {
  description = "CloudWatch Logs retention days"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# OpenSearch master role trust
# 信頼するプリンシパル (AssumeRole 可能な IAM ロール / ユーザー) を明示列挙する。
# 「同一アカウントの root をブランケットで信頼する」設計は、同一アカウント内の任意の
# 広い sts:AssumeRole 権限を持つプリンシパルが OpenSearch superuser に昇格できるため禁止。
# 運用ロール (IAM Identity Center 経由の管理者ロール ARN) と、検索 / 投入用 Lambda
# 実行ロール ARN のみを列挙する。
# -----------------------------------------------------------------------------
variable "opensearch_master_trusted_role_arns" {
  description = "List of IAM role/user ARNs allowed to AssumeRole into opensearch_master. Must enumerate operator roles (e.g., IAM Identity Center admin role) and Lambda execution roles explicitly; cross-account root principals are not allowed."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for a in var.opensearch_master_trusted_role_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:(role|user)/", a))
    ])
    error_message = "Each entry of opensearch_master_trusted_role_arns must be a fully-qualified IAM role or user ARN (arn:aws:iam::<account>:role/<name> or arn:aws:iam::<account>:user/<name>)."
  }

  validation {
    condition = alltrue([
      for a in var.opensearch_master_trusted_role_arns :
      !can(regex(":root$", a))
    ])
    error_message = "Account-root principals (arn:aws:iam::<account>:root) are not allowed; enumerate specific roles or users to prevent privilege escalation from any in-account principal."
  }
}
