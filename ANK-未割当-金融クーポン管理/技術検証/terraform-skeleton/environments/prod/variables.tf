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

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "本環境で作成する IAM Role 全てに付与する Permissions Boundary ARN。CI apply role 側の RequireBoundaryOnRoleCreate Deny を満たすため、IAM Role を作るモジュール (vpc flow_logs / iam 配下のロール) に必ず渡す。PF 集中の場合は PF が用意した boundary、案件で作成する場合は iam モジュールの cicd_apply_boundary を指す。CI からは secrets.IAM_PERMISSIONS_BOUNDARY_ARN_COUPON_<env> を TF_VAR 経由で供給する。default=null は plan を通すための便宜であり、未指定での apply は IAM Deny で必ず失敗する (=設定漏れを早期検出する設計)。"
  default     = null
}
