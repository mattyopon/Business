variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "aws_region" {
  type        = string
  description = "AWS リージョン"
  default     = "ap-northeast-1"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN (CloudWatch Logs / ECS Exec 暗号化)"
}

variable "services" {
  type = map(object({
    type                   = string                   # "service" or "task"
    image                  = string
    cpu                    = string                   # vCPU x 1024 (例: "1024" = 1 vCPU)
    memory                 = string                   # MB (例: "2048" = 2 GB)
    port                   = number                   # 0 = no port
    desired_count          = number
    auto_scaling_enabled   = bool
    min_capacity           = number
    max_capacity           = number
    cpu_target             = number
    subnet_ids             = list(string)
    security_group_ids     = list(string)
    target_group_arn       = string                   # null = no ALB
    execution_role_arn     = string
    task_role_arn          = string
    environment            = list(object({ name = string, value = string }))
    secrets                = list(object({ name = string, valueFrom = string }))
  }))
  description = "ECS Service / Task 定義"
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
