variable "prefix" {
  type        = string
  description = "リソース命名 prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR (Interface endpoint SG の inbound rule 用)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Interface endpoint をデプロイする Private Subnet ID リスト (AZ 数だけ用意)"
}

variable "route_table_ids" {
  type        = list(string)
  description = "Gateway endpoint (S3/DynamoDB) の route table ID リスト"
}

variable "org_id" {
  type        = string
  description = "AWS Organizations ID (S3 gateway endpoint policy で aws:PrincipalOrgID 制約に使用)。null の場合は account 内に scope"
  default     = null
}

variable "enable_s3_gateway" {
  type        = bool
  description = "S3 Gateway endpoint を作成"
  default     = true
}

variable "enable_dynamodb_gateway" {
  type        = bool
  description = "DynamoDB Gateway endpoint を作成 (Terraform state lock 用にも有効)"
  default     = true
}

variable "interface_endpoint_services" {
  type        = list(string)
  description = "Interface endpoint を作る AWS サービス名 (com.amazonaws.<region>. の後ろ部分)。例: kms, secretsmanager, sts, logs, ecr.api, ecr.dkr, monitoring, ssm, ssmmessages, ec2messages, securityhub, guardduty, config"
  default = [
    "kms",
    "secretsmanager",
    "sts",
    "logs",
    "monitoring",
    "ecr.api",
    "ecr.dkr",
    "ssm",
    "ssmmessages",
    "ec2messages",
    "events",
    "sns",
    "sqs",
  ]
}

variable "tags" {
  type        = map(string)
  description = "追加タグ"
  default     = {}
}
