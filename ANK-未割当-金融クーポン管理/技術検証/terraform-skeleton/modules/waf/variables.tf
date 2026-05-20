variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "scope" {
  type        = string
  description = "WAF scope: REGIONAL (ALB/API GW) or CLOUDFRONT (us-east-1 のみ)"
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope は REGIONAL または CLOUDFRONT である必要があります。"
  }
}

variable "rate_limit_per_5min" {
  type        = number
  description = "IP あたり 5 分間のリクエスト数閾値 (超過で block)"
  default     = 2000
}

variable "geo_block_country_codes" {
  type        = list(string)
  description = "Geo block 対象国 ISO 3166-1 alpha-2 コードリスト。空配列で無効化。日本向けサービスで CN/RU/KP/IR 等を遮断する例: [\"CN\", \"RU\", \"KP\", \"IR\"]"
  default     = []
}

variable "enable_logging" {
  type        = bool
  description = "WAF ログを CloudWatch Logs に出力 (PCI-DSS Req10 / FISC 監査要件)"
  default     = true
}

variable "log_retention_days" {
  type        = number
  description = "WAF CloudWatch Logs 保管日数。S3 で長期保管する場合は短くても良い"
  default     = 90
}

variable "kms_key_arn" {
  type        = string
  description = "WAF CloudWatch Logs 暗号化用 KMS Key ARN"
  default     = null
}

variable "alb_arns" {
  type        = list(string)
  description = "アタッチする ALB ARN リスト"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
