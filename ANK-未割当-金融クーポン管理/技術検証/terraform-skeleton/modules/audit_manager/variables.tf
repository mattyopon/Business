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

# CodeRabbit Major 対応 (2026-05-20): audit_owner role の信頼ポリシーを least-privilege 化。
# 旧設計は Principal = account_id (account root) でアカウント全体を信頼していた。
# AWS 公式ガイダンス (https://aws.amazon.com/blogs/security/how-to-use-trust-policies-with-iam-roles/)
# に従い、明示的な principal ARN を必須化する。
variable "audit_owner_trusted_principal_arns" {
  type        = list(string)
  description = "audit_owner IAM Role を AssumeRole 可能な principal ARN のリスト (例: ['arn:aws:iam::ACCOUNT_ID:role/AWSReservedSSO_AuditAdmin_xxxx', 'arn:aws:iam::ACCOUNT_ID:user/auditor1'])。空リストだとアカウント全体を信頼する非推奨パターンとなるため precondition で阻止する"
  default     = []
}

variable "audit_owner_principal_arn_like_patterns" {
  type        = list(string)
  description = "SSO 連携で principal ARN suffix が動的な場合に使用する ArnLike 条件パターンのリスト (例: ['arn:aws:iam::ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AuditAdmin_*'])。指定すると Condition.ArnLike.aws:PrincipalArn として trust policy に追加される"
  default     = []
}

variable "reports_bucket_name" {
  type        = string
  description = "Audit Manager evidence/assessment report の配信先 S3 バケット名。Object Lock COMPLIANCE 推奨。enable=true かつ enable_*_assessment=true のとき必須 (null だと assessment 作成で fail する)"
  default     = null
}

variable "enable_pci_assessment" {
  type        = bool
  description = "PCI DSS assessment を有効化 (決済 PAN を扱う場合 true)。有効化する場合は reports_bucket_name の指定が必須 (precondition で強制)"
  default     = false
}

variable "pci_framework_name" {
  type        = string
  description = "参照する PCI 標準フレームワーク名 (AWS Audit Manager が提供する正確な名前)。出典: https://docs.aws.amazon.com/audit-manager/latest/userguide/pci-v4.html"
  # PCI DSS v4.0 が現行最新 (出典: https://docs.aws.amazon.com/audit-manager/latest/userguide/framework-overviews.html)。
  # v3.2.1 を選択する場合は "PCI DSS V3.2.1" を指定。
  default = "Payment Card Industry Data Security Standard (PCI DSS) v4.0"
}

variable "enable_nist_assessment" {
  type        = bool
  description = "NIST 800-53 r5 assessment を有効化 (J-SOX/内部統制重視)。有効化する場合は reports_bucket_name の指定が必須 (precondition で強制)"
  default     = false
}

variable "nist_framework_name" {
  type        = string
  description = "参照する NIST 800-53 標準フレームワーク名 (AWS Audit Manager の正確な名前)。出典: https://docs.aws.amazon.com/audit-manager/latest/userguide/NIST800-53r5.html"
  default     = "NIST 800-53 Rev 5: Security and Privacy Controls for Information Systems and Organizations"
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
