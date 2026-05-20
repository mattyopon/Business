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

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
