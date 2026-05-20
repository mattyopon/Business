variable "prefix" {
  type        = string
  description = "リソース命名 prefix (例: coupon-prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR ブロック"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr は有効な CIDR である必要があります。"
  }
}

variable "az_count" {
  type        = number
  description = "AZ 数 (2 or 3)"
  default     = 3
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count は 2 または 3 である必要があります。"
  }
}

variable "create_nat_gateway" {
  type        = bool
  description = "NAT Gateway を案件側で作成するか (PF 集中の場合は false)"
  default     = false
}

variable "create_isolated_batch_subnet" {
  type        = bool
  description = "バッチ専用 Isolated Subnet を作成するか"
  default     = true
}

variable "enable_flow_logs" {
  type        = bool
  description = "VPC Flow Logs を有効化するか"
  default     = true
}

variable "flow_log_retention_days" {
  type        = number
  description = "VPC Flow Logs の CloudWatch Logs 保管日数"
  default     = 90
}

variable "kms_key_arn" {
  type        = string
  description = "CloudWatch Logs 暗号化用 KMS Key ARN"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
