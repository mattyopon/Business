variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "kms_key_arn" {
  type        = string
  description = "SNS Topic 暗号化用 KMS Key ARN"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN Suffix (CloudWatch Metric 用)"
  default     = null
}

variable "aurora_cluster_id" {
  type        = string
  description = "Aurora Cluster Identifier (CloudWatch Metric 用)"
  default     = null
}

variable "aurora_max_connections" {
  type        = number
  description = "Aurora 最大接続数 (インスタンスクラス依存、例: db.r6g.large = 1000)"
  default     = 1000
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
