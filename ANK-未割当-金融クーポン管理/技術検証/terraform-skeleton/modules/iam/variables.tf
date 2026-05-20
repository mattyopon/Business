variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "secret_arns" {
  type        = list(string)
  description = "ECS Execution Role がアクセス可能な Secrets Manager ARN リスト"
  default     = []
}

variable "create_github_oidc_provider" {
  type        = bool
  description = "GitHub OIDC Provider を本モジュールで作成するか (PF 集中の場合は false)"
  default     = false
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "既存 GitHub OIDC Provider ARN (create_github_oidc_provider = false 時)"
  default     = null
}

variable "create_cicd_roles" {
  type        = bool
  description = "CI/CD 用 IAM Role を作成するか"
  default     = true
}

variable "github_org" {
  type        = string
  description = "GitHub Organization 名"
  default     = ""
}

variable "github_repo" {
  type        = string
  description = "GitHub Repository 名"
  default     = ""
}

variable "aws_account_id" {
  type        = string
  description = "本モジュールをデプロイする AWS アカウント ID (CI/CD Apply Role の Resource ARN 解決に使用)"
}

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "本モジュールが作成する IAM Role に付与する Permissions Boundary ARN を外部から渡す場合に指定。null かつ create_cicd_roles=true の場合は本モジュール内で作成する cicd_apply_boundary を自動使用する。create_cicd_roles=false で外部 PF の boundary を使う場合は明示指定。"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
