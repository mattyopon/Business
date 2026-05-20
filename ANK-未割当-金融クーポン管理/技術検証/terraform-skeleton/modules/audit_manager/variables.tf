variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "enable" {
  type        = bool
  description = "Audit Manager 全体を有効化 (account registration + assessments)。false で全リソース count=0"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Audit Manager evidence 暗号化用 KMS Key ARN。null で AWS-managed key を使用"
  default     = null
}

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role に付与する Permissions Boundary ARN"
  default     = null
}

variable "reports_bucket_name" {
  type        = string
  description = "Audit Manager evidence/assessment report の配信先 S3 バケット名。Object Lock COMPLIANCE 推奨。enable=true かつ enable_*_assessment=true のとき必須 (null だと assessment 作成で fail する)"
  default     = null
}

variable "enable_pci_assessment" {
  type        = bool
  description = "PCI DSS assessment を有効化 (決済 PAN を扱う場合 true)"
  default     = false
}

variable "pci_framework_name" {
  type        = string
  description = "参照する PCI 標準フレームワーク名 (AWS Audit Manager が提供する名前)"
  default     = "PCI DSS V3.2.1"
}

variable "enable_nist_assessment" {
  type        = bool
  description = "NIST 800-53 r5 assessment を有効化 (J-SOX/内部統制重視)"
  default     = true
}

variable "nist_framework_name" {
  type        = string
  description = "参照する NIST 800-53 標準フレームワーク名"
  default     = "NIST 800-53 (Rev. 5) Low-Moderate-High Baseline"
}

variable "assessment_target_services" {
  type        = list(string)
  description = "Assessment の対象 AWS サービス (audit-manager の AWS service name)。空配列だと scope service 未指定"
  default = [
    "Amazon S3",
    "Amazon RDS",
    "Amazon EC2",
    "Amazon VPC",
    "AWS IAM",
    "AWS KMS",
    "AWS CloudTrail",
    "AWS Config",
    "Amazon CloudWatch",
    "AWS Secrets Manager",
    "Amazon ECS",
    "Amazon GuardDuty",
    "AWS Security Hub",
    "Amazon Macie",
    "Amazon Inspector",
  ]
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
