variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "log_bucket_name" {
  type        = string
  description = "CloudTrail ログ配信先 S3 バケット名 (Object Lock COMPLIANCE 7年推奨)"
}

variable "kms_key_arn" {
  type        = string
  description = "CloudTrail 用 KMS Key ARN (CloudWatch Logs + S3 SSE-KMS 兼用想定)"
}

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role に付与する Permissions Boundary ARN"
  default     = null
}

variable "cloudwatch_logs_retention_days" {
  type        = number
  description = "CloudWatch Logs 保管日数。S3 側で長期保管 (Object Lock 7年) するため CWLog 側は短くても良い"
  default     = 90
}

variable "is_organization_trail" {
  type        = bool
  description = "Organization 配下で組織トレイルとして作成するか (PF 集中の場合は audit account 側で true、本 account では false)"
  default     = false
}

variable "enable_cloudtrail_lake" {
  type        = bool
  description = "CloudTrail Lake (SQL 検索可能な event data store) を有効化"
  default     = true
}

variable "cloudtrail_lake_retention_days" {
  type        = number
  description = "CloudTrail Lake 保管日数 (最長 2557 日 = 7年)"
  default     = 2557
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
