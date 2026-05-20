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
# CloudTrail モジュール
#
# FISC 第11版 4.5 / PCI-DSS v4.0 Req10 / 金融庁 GL "監査ログの完全性"
# が要求する CloudTrail multi-region + log file integrity validation を実装。
#
# - 全 region + 全管理イベント + データイベント (S3/Lambda)
# - log file integrity validation 有効化 (改竄検知)
# - S3 配信先は Object Lock COMPLIANCE 推奨 (本モジュールでは bucket 名を受け取る)
# - CloudWatch Logs にも同時配信 (リアルタイム検知用)
# - SSE-KMS で暗号化
# =============================================================================

resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.prefix}"
  retention_in_days = var.cloudwatch_logs_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_iam_role" "trail_to_cwlogs" {
  name                 = "${var.prefix}-cloudtrail-to-cwlogs-role"
  permissions_boundary = var.iam_role_permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "trail_to_cwlogs" {
  name = "${var.prefix}-cloudtrail-to-cwlogs-policy"
  role = aws_iam_role.trail_to_cwlogs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.prefix}-trail"
  s3_bucket_name                = var.log_bucket_name
  s3_key_prefix                 = "cloudtrail/${data.aws_caller_identity.current.account_id}"
  include_global_service_events = true
  is_multi_region_trail         = true # FISC: 全 region 監査必須
  is_organization_trail         = var.is_organization_trail
  enable_log_file_validation    = true # 改竄検知 (SHA-256 ハッシュ)
  kms_key_id                    = var.kms_key_arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_to_cwlogs.arn

  # advanced_event_selector で management + S3 data + Lambda data を統合
  # (event_selector とは併用不可なため advanced 側に集約)
  advanced_event_selector {
    name = "Log all management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  advanced_event_selector {
    name = "Log S3 object-level data events (excluding loop-back)"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
    # CloudTrail 配信先 bucket 自身を除外して循環ログを防止
    field_selector {
      field           = "resources.ARN"
      not_starts_with = ["arn:aws:s3:::${var.log_bucket_name}/"]
    }
  }

  advanced_event_selector {
    name = "Log Lambda data events"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::Lambda::Function"]
    }
  }

  tags = var.tags
}

# CloudTrail Lake — 90日超え保管 + SQL 検索 (PCI-DSS 1年 / FISC 7年)
resource "aws_cloudtrail_event_data_store" "lake" {
  count = var.enable_cloudtrail_lake ? 1 : 0

  name                           = "${var.prefix}-trail-lake"
  retention_period               = var.cloudtrail_lake_retention_days
  multi_region_enabled           = true
  organization_enabled           = var.is_organization_trail
  termination_protection_enabled = true

  advanced_event_selector {
    name = "All management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  tags = var.tags
}

data "aws_caller_identity" "current" {}
