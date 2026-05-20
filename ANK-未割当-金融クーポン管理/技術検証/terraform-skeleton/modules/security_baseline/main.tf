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
# Security Baseline モジュール
#
# 金融庁「金融分野におけるサイバーセキュリティに関するガイドライン」(2024-10) +
# FISC 安全対策基準 第11版 + AWS Well-Architected FSI Lens for FISC が求める
# 基本的なセキュリティモニタリング群を集約。
#
# - GuardDuty: 脅威検知 (VPCFlowLogs/DNS/CloudTrail/S3/RDS/EKS/Malware/Lambda)
# - Security Hub: CSPM (FSBP / PCI v4 / CIS Foundations Benchmark)
# - AWS Config: リソース構成変更記録 + Conformance Pack
# - Macie: S3 内 PII / 機密データ自動検出
# - Inspector v2: ECR / EC2 / Lambda 脆弱性スキャン
# - IAM Access Analyzer: 外部公開アクセス + 未使用権限分析
#
# 注: AWS Organizations 配下 (PF 集中管理) では各サービスを
# delegated administrator account で集中受信するため、本モジュールは
# delegate 済み前提で member account 側を有効化する。Org 未利用時は
# 単一アカウントで完結。
# =============================================================================

# -----------------------------------------------------------------------------
# GuardDuty
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES" # FISC: P1 検知の遅延最小化

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = var.guardduty_enable_eks
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.guardduty_enable_malware
        }
      }
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Security Hub (CSPM)
# -----------------------------------------------------------------------------
resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

# AWS Foundational Security Best Practices (FSBP) — 全業界 baseline
resource "aws_securityhub_standards_subscription" "fsbp" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# PCI-DSS v3.2.1 (本案件のクーポン管理が決済 PAN を扱う場合に必須)
resource "aws_securityhub_standards_subscription" "pci_dss" {
  count = var.enable_security_hub && var.security_hub_enable_pci ? 1 : 0

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.this]
}

# CIS AWS Foundations Benchmark v3.0.0 — 金融庁 GL の基本対応事項に合致
resource "aws_securityhub_standards_subscription" "cis" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/3.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# NIST SP 800-53 r5 — J-SOX / 内部統制を意識する場合
resource "aws_securityhub_standards_subscription" "nist" {
  count = var.enable_security_hub && var.security_hub_enable_nist ? 1 : 0

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# -----------------------------------------------------------------------------
# AWS Config (構成変更記録 + Conformance Pack)
# -----------------------------------------------------------------------------
resource "aws_config_configuration_recorder" "this" {
  count = var.enable_config ? 1 : 0

  name     = "${var.prefix}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.config_include_global # us-east-1 で 1 つだけ true
  }
}

resource "aws_config_delivery_channel" "this" {
  count = var.enable_config ? 1 : 0

  name           = "${var.prefix}-config-delivery"
  s3_bucket_name = var.config_log_bucket_name # 集約 audit account の S3 を指す想定
  s3_key_prefix  = "config/${data.aws_caller_identity.current.account_id}"
  sns_topic_arn  = var.config_sns_topic_arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  count = var.enable_config ? 1 : 0

  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_iam_role" "config" {
  count                = var.enable_config ? 1 : 0
  name                 = "${var.prefix}-config-recorder-role"
  permissions_boundary = var.iam_role_permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# -----------------------------------------------------------------------------
# Macie (S3 PII / 機密データ検出)
# -----------------------------------------------------------------------------
resource "aws_macie2_account" "this" {
  count = var.enable_macie ? 1 : 0

  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

# 日次フルスキャン: audit-logs / reports など PII を含む可能性のあるバケットを対象
resource "aws_macie2_classification_job" "daily" {
  count = var.enable_macie && length(var.macie_target_bucket_names) > 0 ? 1 : 0

  job_type = "SCHEDULED"
  name     = "${var.prefix}-macie-daily-pii-scan"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = var.macie_target_bucket_names
    }
  }

  schedule_frequency {
    daily_schedule = true
  }

  depends_on = [aws_macie2_account.this]
}

# -----------------------------------------------------------------------------
# Inspector v2 (ECR / EC2 / Lambda 脆弱性スキャン)
# -----------------------------------------------------------------------------
resource "aws_inspector2_enabler" "this" {
  count = var.enable_inspector ? 1 : 0

  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = var.inspector_resource_types # ["ECR", "EC2", "LAMBDA"] 等
}

# -----------------------------------------------------------------------------
# IAM Access Analyzer (外部公開 + 未使用権限)
# -----------------------------------------------------------------------------
resource "aws_accessanalyzer_analyzer" "external_access" {
  count = var.enable_access_analyzer ? 1 : 0

  analyzer_name = "${var.prefix}-external-access-analyzer"
  type          = "ACCOUNT" # Org 配下なら "ORGANIZATION" に変更
  tags          = var.tags
}

resource "aws_accessanalyzer_analyzer" "unused_access" {
  count = var.enable_access_analyzer && var.access_analyzer_enable_unused ? 1 : 0

  analyzer_name = "${var.prefix}-unused-access-analyzer"
  type          = "ACCOUNT_UNUSED_ACCESS"
  configuration {
    unused_access {
      unused_access_age = 90 # 90日未使用で finding
    }
  }
  tags = var.tags
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
