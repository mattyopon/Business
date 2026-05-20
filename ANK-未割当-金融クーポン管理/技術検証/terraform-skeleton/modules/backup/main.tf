terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

# =============================================================================
# AWS Backup モジュール
#
# FISC 第11版 5.1 / FSI Lens Reliability pillar / 金融庁 GL 業務継続:
# - Multi-AZ では足りない (region 障害対策が必要)
# - cross-region copy + (理想は) cross-account copy で改竄/ランサム対策
# - Vault Lock (governance / compliance) で削除保護
#
# 本モジュールは primary region 側の vault と plan を作成し、
# cross-region copy 先 vault は別 provider alias で作成する想定。
# =============================================================================

resource "aws_backup_vault" "primary" {
  name        = "${var.prefix}-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = var.tags
}

# Vault Lock — COMPLIANCE モードは事実上不可逆 (root でも変更不可)
resource "aws_backup_vault_lock_configuration" "primary" {
  count = var.enable_vault_lock ? 1 : 0

  backup_vault_name   = aws_backup_vault.primary.name
  changeable_for_days = var.vault_lock_changeable_for_days # 3日以上推奨
  min_retention_days  = var.min_retention_days
  max_retention_days  = var.max_retention_days
}

# Backup Plan
resource "aws_backup_plan" "this" {
  name = "${var.prefix}-backup-plan"

  rule {
    rule_name                = "daily-35d"
    target_vault_name        = aws_backup_vault.primary.name
    schedule                 = "cron(0 17 ? * * *)" # UTC 17:00 = JST 02:00
    start_window             = 60
    completion_window        = 360
    enable_continuous_backup = var.enable_continuous_backup # PITR

    lifecycle {
      cold_storage_after = 30
      delete_after       = var.daily_retention_days
    }

    dynamic "copy_action" {
      for_each = var.cross_region_destination_vault_arn != null ? [1] : []
      content {
        destination_vault_arn = var.cross_region_destination_vault_arn
        lifecycle {
          cold_storage_after = 30
          delete_after       = var.daily_retention_days
        }
      }
    }
  }

  rule {
    rule_name         = "monthly-7y"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 17 1 * ? *)" # 月初 UTC 17:00
    start_window      = 60
    completion_window = 720

    lifecycle {
      cold_storage_after = 90
      delete_after       = 2557 # 7年 (FISC / 会計監査の典型)
    }

    dynamic "copy_action" {
      for_each = var.cross_region_destination_vault_arn != null ? [1] : []
      content {
        destination_vault_arn = var.cross_region_destination_vault_arn
        lifecycle {
          cold_storage_after = 90
          delete_after       = 2557
        }
      }
    }
  }

  advanced_backup_setting {
    backup_options = { WindowsVSS = "disabled" }
    resource_type  = "EC2"
  }

  tags = var.tags
}

# Backup Selection: タグ "BackupPlan=daily-monthly" が付いたリソースを自動対象化
resource "aws_iam_role" "backup" {
  name                 = "${var.prefix}-backup-service-role"
  permissions_boundary = var.iam_role_permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_selection" "tag_based" {
  name         = "${var.prefix}-backup-selection-tag"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.this.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "BackupPlan"
    value = "daily-monthly"
  }
}
