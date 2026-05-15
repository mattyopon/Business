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
# 広域 CIDR は許可しない。validation は「プレフィックス長」で機械的に強制する
# (denylist 方式は 10.1.0.0/16 や 10.0.0.0/9 などが素通りするため不採用)。
variable "bastion_cidr" {
  description = "Bastion host subnet CIDR for GKE master authorized networks. Must have prefix /24 or longer (i.e., a small subnet). Wide ranges are rejected to prevent reopening master endpoint."
  type        = string
  default     = "10.0.16.0/28"

  validation {
    # 1) 形式チェック: a.b.c.d/p の形であること
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$", var.bastion_cidr))
    error_message = "bastion_cidr must be a valid IPv4 CIDR (a.b.c.d/p where 0 <= p <= 32)."
  }

  validation {
    # 2) プレフィックス長チェック: /24 以上の narrow な範囲に限定
    #    /24 (256 IP) は踏み台サブネットとして実用上の上限。/25, /26, /27, /28 が一般的な踏み台サイズ。
    #    /23 以下のサイズ (/8, /16 等) は控訴。これにより 10.0.0.0/8 / 10.1.0.0/16 等を全てブロック。
    condition     = tonumber(regex("/([0-9]+)$", var.bastion_cidr)[0]) >= 24
    error_message = "bastion_cidr must have prefix length /24 or longer (smaller subnet). Wide ranges such as /8, /16, /20, /23 reopen the GKE master endpoint and are forbidden."
  }

  validation {
    # 3) 明示的なブロックリスト (RFC1918 全域 / 0.0.0.0/0) — 上記 2) で既に弾かれるが、
    #    エラーメッセージ上で「これらは禁止」と明示するための補助チェック。
    condition     = !contains(["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "0.0.0.0/0"], var.bastion_cidr)
    error_message = "bastion_cidr cannot be a full RFC1918 range or 0.0.0.0/0."
  }
}
