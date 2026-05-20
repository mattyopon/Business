variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role に付与する Permissions Boundary ARN"
  default     = null
}

# ---- GuardDuty ----
variable "enable_guardduty" {
  type        = bool
  description = "GuardDuty を有効化 (PF 集中受信なら member account で有効化のみ)"
  default     = true
}

variable "guardduty_enable_eks" {
  type        = bool
  description = "EKS Audit Logs 監視を有効化"
  default     = false
}

variable "guardduty_enable_malware" {
  type        = bool
  description = "EBS Malware Protection を有効化"
  default     = true
}

# ---- Security Hub ----
variable "enable_security_hub" {
  type        = bool
  description = "Security Hub を有効化"
  default     = true
}

variable "security_hub_enable_pci" {
  type        = bool
  description = "PCI-DSS standard を有効化 (決済 PAN を扱う場合 true)"
  default     = false
}

variable "security_hub_enable_nist" {
  type        = bool
  description = "NIST 800-53 standard を有効化 (J-SOX / 内部統制重視で true)"
  default     = false
}

# ---- AWS Config ----
variable "enable_config" {
  type        = bool
  description = "AWS Config を有効化"
  default     = true
}

variable "config_include_global" {
  type        = bool
  description = "IAM 等のグローバルリソースを記録対象に含める (us-east-1 など 1 region でのみ true 推奨)"
  default     = false
}

variable "config_log_bucket_name" {
  type        = string
  description = "AWS Config 配信先 S3 バケット名 (audit account 側で provision された集約バケットを指す想定)"
  default     = null
}

variable "config_sns_topic_arn" {
  type        = string
  description = "AWS Config 通知用 SNS Topic ARN (任意)"
  default     = null
}

# ---- Macie ----
variable "enable_macie" {
  type        = bool
  description = "Macie を有効化 (S3 PII / 機密データ自動検出)"
  default     = true
}

variable "macie_target_bucket_names" {
  type        = list(string)
  description = "Macie 日次スキャン対象の S3 バケット名リスト"
  default     = []
}

# ---- Inspector v2 ----
variable "enable_inspector" {
  type        = bool
  description = "Inspector v2 を有効化"
  default     = true
}

variable "inspector_resource_types" {
  type        = list(string)
  description = "Inspector スキャン対象 (ECR / EC2 / LAMBDA)"
  default     = ["ECR", "EC2", "LAMBDA"]
}

# ---- IAM Access Analyzer ----
variable "enable_access_analyzer" {
  type        = bool
  description = "IAM Access Analyzer を有効化"
  default     = true
}

variable "access_analyzer_enable_unused" {
  type        = bool
  description = "未使用アクセス分析 (90日基準) を有効化 (有償)"
  default     = true
}
