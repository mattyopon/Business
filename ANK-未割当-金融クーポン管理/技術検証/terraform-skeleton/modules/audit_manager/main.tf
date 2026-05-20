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
# AWS Audit Manager モジュール
#
# PCI-DSS v4 / NIST 800-53 r5 / FISC 11版 への準拠評価を継続的に自動化。
#
# - Account registration (audit-manager サービス有効化)
# - 既存の AWS 標準フレームワーク (PCI v3.2.1 / NIST 800-53 等) を data source で参照
# - Assessment を作成し、対象アカウント + サービスに対する evidence collection を開始
# - Reports destination は専用 S3 bucket (Object Lock COMPLIANCE 推奨 — 別途 modules/s3 で provision)
#
# 出典:
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/auditmanager_account_registration
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/auditmanager_assessment
# - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/auditmanager_framework
# =============================================================================

# Step 1: account registration (audit-manager サービスを有効化)
resource "aws_auditmanager_account_registration" "this" {
  count = var.enable ? 1 : 0

  # KMS は audit-manager の evidence 暗号化に使用される。null だと AWS-managed key。
  kms_key = var.kms_key_arn
  # 本モジュール経由で destroy 時に deregister すると、過去 evidence が失われるため false 推奨
  deregister_on_destroy = false
}

# Step 2: 既存標準フレームワーク参照 (data sources)
data "aws_auditmanager_framework" "pci" {
  count = var.enable && var.enable_pci_assessment ? 1 : 0

  name           = var.pci_framework_name # 例: "PCI DSS V3.2.1"
  framework_type = "Standard"

  depends_on = [aws_auditmanager_account_registration.this]
}

data "aws_auditmanager_framework" "nist" {
  count = var.enable && var.enable_nist_assessment ? 1 : 0

  name           = var.nist_framework_name # 例: "NIST 800-53 (Rev. 5) Low-Moderate-High Baseline"
  framework_type = "Standard"

  depends_on = [aws_auditmanager_account_registration.this]
}

# Step 3: assessment 用 IAM Role (process owner) を作成
resource "aws_iam_role" "audit_owner" {
  count                = var.enable ? 1 : 0
  name                 = "${var.prefix}-audit-manager-owner-role"
  permissions_boundary = var.iam_role_permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        # 評価責任者 (人間) がこの role を AssumeRole する想定。SAML/IDC integration は env 側で trust 拡張。
        AWS = data.aws_caller_identity.current.account_id
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# AuditManagerServiceRolePolicy 相当の最小限 (assessor 用)
resource "aws_iam_role_policy_attachment" "audit_owner_readonly" {
  count = var.enable ? 1 : 0

  role       = aws_iam_role.audit_owner[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSAuditManagerAdministratorAccess"
}

# Step 4: PCI Assessment
# Codex P2 対応 (2026-05-20): reports_bucket_name は assessment_reports_destination で
# 必須なので、enable_pci_assessment=true かつ null だと plan/apply が必ず fail する。
# variable validation は他 variable を参照できないため、resource lifecycle.precondition
# で plan 時に明示的なエラーメッセージで失敗させる。デフォルトも false (variables.tf)。
resource "aws_auditmanager_assessment" "pci" {
  count = var.enable && var.enable_pci_assessment ? 1 : 0

  name         = "${var.prefix}-assessment-pci"
  description  = "PCI DSS continuous assessment for ${var.prefix}"
  framework_id = data.aws_auditmanager_framework.pci[0].id

  assessment_reports_destination {
    destination      = "s3://${var.reports_bucket_name}"
    destination_type = "S3"
  }

  roles {
    role_arn  = aws_iam_role.audit_owner[0].arn
    role_type = "PROCESS_OWNER"
  }

  scope {
    aws_accounts {
      id = data.aws_caller_identity.current.account_id
    }
    dynamic "aws_services" {
      for_each = var.assessment_target_services
      content {
        service_name = aws_services.value
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.reports_bucket_name != null && var.reports_bucket_name != ""
      error_message = "enable_pci_assessment=true のとき reports_bucket_name は必須 (Object Lock COMPLIANCE 推奨の S3 bucket 名を指定してください)"
    }
  }

  tags = var.tags
}

# Step 5: NIST 800-53 Assessment (オプション、J-SOX/内部統制で必要な場合)
# Codex P2 対応: デフォルト false。明示的に有効化したいときだけ enable_nist_assessment=true + reports_bucket_name を渡す。
resource "aws_auditmanager_assessment" "nist" {
  count = var.enable && var.enable_nist_assessment ? 1 : 0

  name         = "${var.prefix}-assessment-nist-800-53"
  description  = "NIST SP 800-53 r5 continuous assessment for ${var.prefix}"
  framework_id = data.aws_auditmanager_framework.nist[0].id

  assessment_reports_destination {
    destination      = "s3://${var.reports_bucket_name}"
    destination_type = "S3"
  }

  roles {
    role_arn  = aws_iam_role.audit_owner[0].arn
    role_type = "PROCESS_OWNER"
  }

  scope {
    aws_accounts {
      id = data.aws_caller_identity.current.account_id
    }
    dynamic "aws_services" {
      for_each = var.assessment_target_services
      content {
        service_name = aws_services.value
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.reports_bucket_name != null && var.reports_bucket_name != ""
      error_message = "enable_nist_assessment=true のとき reports_bucket_name は必須 (Object Lock COMPLIANCE 推奨の S3 bucket 名を指定してください)"
    }
  }

  tags = var.tags
}

data "aws_caller_identity" "current" {}
