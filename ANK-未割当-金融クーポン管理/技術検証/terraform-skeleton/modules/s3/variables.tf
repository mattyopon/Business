variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "buckets" {
  type = map(object({
    force_destroy      = bool
    versioning_enabled = bool
    object_lock_mode   = string # null / "GOVERNANCE" / "COMPLIANCE"
    object_lock_days   = number
    kms_key_arn        = string
    lifecycle_rules = list(object({
      id              = string
      transitions     = list(object({ days = number, storage_class = string }))
      expiration_days = number
    }))
  }))
  description = "S3 バケット定義"
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
