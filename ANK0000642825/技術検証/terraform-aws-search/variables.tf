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
#
# 本構成は **同一アカウント内** のロールのみを信頼する設計に固定している。
# `aws:PrincipalAccount` Condition と `expected_account_id` を組み合わせて、
# (a) 各 ARN の account ID が `expected_account_id` と一致することを variable 段階で保証
# (b) `expected_account_id` が Terraform 認証先の caller account と一致することを
#     resource 適用時に precondition で保証 (main.tf 側)
# することで、cross-account ARN が混入して trust policy に書かれたものの
# `aws:PrincipalAccount` で runtime AssumeRole が deny される silent failure を防ぐ。
# Cross-account 利用が必要になった場合は、この variable と main.tf の Condition を
# 同時に見直すこと (片方だけ緩めると不整合になる)。
# -----------------------------------------------------------------------------
variable "expected_account_id" {
  description = "12-digit AWS account ID that owns the OpenSearch master role and every entry of opensearch_master_trusted_role_arns. Used both as the value of the `aws:PrincipalAccount` Condition in the trust policy and as a cross-variable validation reference for opensearch_master_trusted_role_arns. Must equal the account in which Terraform authenticates (verified at apply time via lifecycle.precondition on aws_iam_role.opensearch_master)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID (e.g., \"123456789012\")."
  }
}

variable "opensearch_master_trusted_role_arns" {
  description = "List of IAM role/user ARNs allowed to AssumeRole into opensearch_master. **Required (no default).** Every ARN must belong to var.expected_account_id (same-account trust); cross-account ARNs are rejected at plan time to avoid trust policy / aws:PrincipalAccount Condition silent mismatch. Must enumerate operator roles (e.g., IAM Identity Center admin role) and Lambda execution roles explicitly; account-root principals are not allowed."
  type        = list(string)

  validation {
    condition     = length(var.opensearch_master_trusted_role_arns) > 0
    error_message = "opensearch_master_trusted_role_arns must contain at least one entry. Specify the operator role (e.g., IAM Identity Center admin role ARN) and/or Lambda execution role ARNs that are allowed to administer the OpenSearch domain."
  }

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

  # Cross-variable validation (Terraform 1.9+ 必須; providers.tf の required_version で担保)。
  # 各 ARN の 5 番目フィールド (account ID) が expected_account_id と一致することを保証する。
  # これがないと、cross-account ARN が trust policy に書かれた一方で
  # main.tf の `aws:PrincipalAccount = var.expected_account_id` Condition で runtime AssumeRole
  # が deny される silent failure が発生する (Codex 22nd loop 指摘)。
  validation {
    condition = alltrue([
      for a in var.opensearch_master_trusted_role_arns :
      split(":", a)[4] == var.expected_account_id
    ])
    error_message = "Every opensearch_master_trusted_role_arns entry must belong to expected_account_id (same-account trust). For cross-account trust, both this validation and the aws:PrincipalAccount Condition in main.tf must be revisited together."
  }
}
