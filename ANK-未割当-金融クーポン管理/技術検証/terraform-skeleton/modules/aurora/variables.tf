variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "engine_version" {
  type        = string
  description = "Aurora PostgreSQL バージョン (例: 16.4)"
  default     = "16.4"
}

variable "cluster_parameter_group_family" {
  type        = string
  description = "Cluster Parameter Group family (例: aurora-postgresql16)"
  default     = "aurora-postgresql16"
}

variable "database_name" {
  type        = string
  description = "初期データベース名"
  default     = "coupon"
}

variable "master_username" {
  type        = string
  description = "Master ユーザ名"
  default     = "coupon_admin"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN (作成時固定、後で変更不可)"
}

variable "db_subnet_group_name" {
  type        = string
  description = "DB Subnet Group 名"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security Group ID リスト"
}

variable "instance_class" {
  type        = string
  description = "DB インスタンスクラス"
  default     = "db.r6g.large"
}

variable "instance_count" {
  type        = number
  description = "DB インスタンス数 (Writer + Reader)"
  default     = 2
  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count は 1 以上である必要があります。"
  }
}

variable "backup_retention_period" {
  type        = number
  description = "Backup 保管日数 (1-35)"
  default     = 35
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "backup_retention_period は 1-35 の範囲である必要があります。"
  }
}

variable "backup_window" {
  type        = string
  description = "Backup 時間帯 (UTC、例: '10:00-11:00' = JST 19:00-20:00)"
  default     = "10:00-11:00"
}

variable "maintenance_window" {
  type        = string
  description = "Maintenance 時間帯 (UTC、例: 'sun:18:00-sun:19:00' = JST sun:03:00-04:00)"
  default     = "sun:18:00-sun:19:00"
}

variable "deletion_protection" {
  type        = bool
  description = "削除保護 (PROD は必須)"
  default     = true
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Performance Insights 有効化"
  default     = true
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Performance Insights 保管日数 (7 or 731)"
  default     = 7
}

variable "enhanced_monitoring_interval" {
  type        = number
  description = "Enhanced Monitoring 粒度 (0/1/5/10/15/30/60 秒。0 は無効)"
  default     = 60
}

variable "enhanced_monitoring_role_arn" {
  type        = string
  description = "Enhanced Monitoring 用 IAM Role ARN"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
