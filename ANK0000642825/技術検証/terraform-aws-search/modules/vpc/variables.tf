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

  validation {
    # Multi-NAT (single_nat_gateway = false) では AZ-local routing を強制するため、
    # private_subnets と public_subnets の数を一致させる必要がある (各 AZ に NAT を 1 つずつ)。
    # 不一致を許すと private_subnets[i] が別 AZ の NAT を踏むことになり、
    # NAT の AZ 障害で他 AZ の private egress が落ちる + cross-AZ 課金が発生する。
    # single_nat_gateway = true (コスト最適化モード) では 1 NAT を全 AZ で共有するため本制約は無効。
    condition     = !var.enable_nat_gateway || var.single_nat_gateway || length(var.private_subnets) == length(var.public_subnets)
    error_message = "When enable_nat_gateway=true and single_nat_gateway=false (multi-NAT, AZ-local routing), length(private_subnets) must equal length(public_subnets). If asymmetric subnet counts are required, set single_nat_gateway=true to use one shared NAT, or add public subnets to match."
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
