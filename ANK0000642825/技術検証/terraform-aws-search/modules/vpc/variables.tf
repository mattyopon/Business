variable "name" {
  description = "VPC name prefix"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway(s) for private subnets. Requires public_subnets to be non-empty (NAT lives in a public subnet)."
  type        = bool
  default     = true

  validation {
    # NAT を有効にしているのに public_subnets が空だと:
    #   - aws_eip.nat / aws_nat_gateway.this が count=0
    #   - private route table の `count.index % length(aws_nat_gateway.this)` が division-by-zero
    #     ([] への modulo) で plan が失敗する。
    # ここで早期にユーザーへ意図を伝えて plan を止める。
    # 注: Terraform v0.13+ では variable validation の condition から他の variable を参照できる。
    condition     = !var.enable_nat_gateway || length(var.public_subnets) > 0
    error_message = "enable_nat_gateway = true requires at least one entry in public_subnets (NAT gateway must live in a public subnet). Either set enable_nat_gateway = false or supply public_subnet CIDRs."
  }
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway across all private subnets (cost saving)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
