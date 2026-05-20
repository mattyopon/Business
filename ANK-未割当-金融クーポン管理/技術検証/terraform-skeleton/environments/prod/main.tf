terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project            = "coupon"
      Environment        = local.env
      Owner              = "coupon-team"
      CostCenter         = var.cost_center
      DataClassification = "confidential"
      ManagedBy          = "terraform"
      Repository         = var.repo_url
    }
  }
}

locals {
  env    = "prod"
  prefix = "coupon-${local.env}"
}

# ---------------------------------------------
# 注意: KMS / IAM Identity Center は PF 側集中管理想定。
# 本ファイルでは PF 側出力 (Remote State) を参照する想定。
# 実装は PF 側ガイドライン受領後に確定。
# ---------------------------------------------

data "aws_caller_identity" "current" {}

# Placeholder: PF 側 KMS Key を参照する場合の data ソース
# data "aws_kms_key" "aurora" {
#   key_id = "alias/coupon-prod-aurora"
# }

module "vpc" {
  source = "../../modules/vpc"

  prefix                            = local.prefix
  vpc_cidr                          = var.vpc_cidr
  az_count                          = 3
  create_nat_gateway                = false # PF 集中想定
  create_isolated_batch_subnet      = true
  enable_flow_logs                  = true
  flow_log_retention_days           = 90
  kms_key_arn                       = var.kms_key_arn_cw_logs # PF or 案件 KMS
  iam_role_permissions_boundary_arn = var.iam_role_permissions_boundary_arn
}

module "aurora" {
  source = "../../modules/aurora"

  prefix               = local.prefix
  engine_version       = "16.4"
  database_name        = "coupon"
  master_username      = "coupon_admin"
  kms_key_arn          = var.kms_key_arn_aurora
  db_subnet_group_name = module.vpc.db_subnet_group_name
  security_group_ids   = [var.sg_aurora_id] # 別途 SG モジュールで作成想定

  instance_class                        = "db.r6g.large"
  instance_count                        = 2
  backup_retention_period               = 35
  backup_window                         = "10:00-11:00"         # JST 19:00-20:00
  maintenance_window                    = "sun:18:00-sun:19:00" # JST sun:03-04
  deletion_protection                   = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enhanced_monitoring_interval          = 60
  enhanced_monitoring_role_arn          = var.iam_role_aurora_monitoring_arn
}

module "s3" {
  source = "../../modules/s3"

  prefix = local.prefix

  buckets = {
    audit-logs = {
      force_destroy      = false
      versioning_enabled = true
      object_lock_mode   = "COMPLIANCE"
      object_lock_days   = 2557 # 7 年 = 2557 日
      kms_key_arn        = var.kms_key_arn_s3_audit
      lifecycle_rules = [
        {
          id = "audit-logs-archive"
          transitions = [
            { days = 90, storage_class = "STANDARD_IA" },
            { days = 365, storage_class = "DEEP_ARCHIVE" }
          ]
          expiration_days = null # 7 年保管なので Object Lock 切れ後に手動削除
        }
      ]
    }
    batch-files = {
      force_destroy      = false
      versioning_enabled = false
      object_lock_mode   = null
      object_lock_days   = 0
      kms_key_arn        = var.kms_key_arn_s3_general
      lifecycle_rules = [
        {
          id = "batch-files-archive"
          transitions = [
            { days = 30, storage_class = "STANDARD_IA" },
            { days = 90, storage_class = "GLACIER_IR" }
          ]
          expiration_days = 365
        }
      ]
    }
    reports = {
      force_destroy      = false
      versioning_enabled = true
      object_lock_mode   = null
      object_lock_days   = 0
      kms_key_arn        = var.kms_key_arn_s3_general
      lifecycle_rules    = []
    }
  }
}

# ECS / Route53 / Monitoring 等は同様に module 呼び出し (省略)
