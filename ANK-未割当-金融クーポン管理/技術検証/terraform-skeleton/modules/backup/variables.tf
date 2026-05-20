variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "kms_key_arn" {
  type        = string
  description = "Backup vault 暗号化用 KMS Key ARN"
}

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role に付与する Permissions Boundary ARN"
  default     = null
}

variable "enable_vault_lock" {
  type        = bool
  description = "Vault Lock を有効化。COMPLIANCE モードは事実上不可逆 (root でも変更不可) なので、運用ルール確定後に true 推奨"
  default     = false
}

variable "vault_lock_changeable_for_days" {
  type        = number
  description = "Vault Lock の変更可能期間 (日)。3 以上で COMPLIANCE モード相当に固定される"
  default     = 3
}

variable "min_retention_days" {
  type        = number
  description = "Vault 内のすべての recovery point の最小保管日数"
  default     = 1
}

variable "max_retention_days" {
  type        = number
  description = "Vault 内のすべての recovery point の最大保管日数"
  default     = 2557 # 7年
}

variable "enable_continuous_backup" {
  type        = bool
  description = "Continuous backup (Point-in-Time Recovery) を有効化"
  default     = true
}

variable "daily_retention_days" {
  type        = number
  description = "日次バックアップの保管日数"
  default     = 35
}

variable "cross_region_destination_vault_arn" {
  type        = string
  description = "Cross-region copy 先 vault ARN。region 障害対策で必須 (ap-northeast-3 / ap-southeast-1 等)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
