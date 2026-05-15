variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "payment-platform"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Environment (production, staging, development)"
  type        = string
  default     = "production"
}

# GKE Master Authorized Networks 用の踏み台ホスト CIDR
# 設計書 01_インフラ設計書.md 「3.x 踏み台・IAP 経由アクセス」と整合させ、
# 10.0.0.0/8 のような広域指定は禁止。踏み台サブネットの実 CIDR を渡すこと。
variable "bastion_cidr" {
  description = "Bastion host subnet CIDR for GKE master authorized networks (must be a narrow CIDR; 10.0.0.0/8 etc. are forbidden)"
  type        = string
  default     = "10.0.16.0/28"

  validation {
    condition     = !contains(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "0.0.0.0/0"], var.bastion_cidr)
    error_message = "bastion_cidr must be a narrow CIDR (e.g., /28). Wide ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 0.0.0.0/0) are forbidden by security baseline."
  }
}
