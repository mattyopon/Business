variable "create_private_zone" {
  type        = bool
  description = "Private Hosted Zone を作成するか"
  default     = true
}

variable "create_public_zone" {
  type        = bool
  description = "Public Hosted Zone を作成するか"
  default     = false
}

variable "private_zone_name" {
  type        = string
  description = "Private Hosted Zone 名 (例: coupon.internal)"
  default     = "coupon.internal"
}

variable "public_zone_name" {
  type        = string
  description = "Public Hosted Zone 名 (例: coupon.example.com)"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "Private Hosted Zone に関連付ける VPC ID"
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
