variable "region" {
  type        = string
  description = "AWS リージョン"
  default     = "ap-northeast-1"
}

variable "cost_center" {
  type        = string
  description = "Cost Center 識別子"
}

variable "repo_url" {
  type        = string
  description = "リポジトリ URL"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR (PF 側から割当)"
}

variable "kms_key_arn_aurora" {
  type        = string
  description = "Aurora 暗号化用 KMS Key ARN"
}

variable "kms_key_arn_s3_audit" {
  type        = string
  description = "S3 audit-logs 暗号化用 KMS Key ARN"
}

variable "kms_key_arn_s3_general" {
  type        = string
  description = "S3 general 暗号化用 KMS Key ARN"
}

variable "kms_key_arn_cw_logs" {
  type        = string
  description = "CloudWatch Logs 暗号化用 KMS Key ARN"
}

variable "sg_aurora_id" {
  type        = string
  description = "Aurora 用 Security Group ID"
}

variable "iam_role_aurora_monitoring_arn" {
  type        = string
  description = "Aurora Enhanced Monitoring IAM Role ARN"
}
