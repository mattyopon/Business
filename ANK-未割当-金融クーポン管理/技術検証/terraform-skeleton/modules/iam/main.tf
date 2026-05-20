terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

# ECS Task Execution Role (共通)
resource "aws_iam_role" "ecs_execution" {
  name = "${var.prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager Read 権限 (ECS Execution Role が秘密値を取得する用)
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.prefix}-ecs-execution-secrets-policy"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      Resource = var.secret_arns
    }]
  })
}

# Aurora Enhanced Monitoring Role
resource "aws_iam_role" "aurora_monitoring" {
  name = "${var.prefix}-aurora-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "aurora_monitoring" {
  role       = aws_iam_role.aurora_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# GitHub OIDC Provider (CI/CD 用、案件側で作成する場合)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

# CI/CD Plan Role (ReadOnly)
resource "aws_iam_role" "cicd_plan" {
  count = var.create_cicd_roles ? 1 : 0

  name = "${var.prefix}-cicd-plan-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cicd_plan_readonly" {
  count = var.create_cicd_roles ? 1 : 0

  role       = aws_iam_role.cicd_plan[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# CI/CD Apply Role (環境別、最小権限のみ)
resource "aws_iam_role" "cicd_apply" {
  count = var.create_cicd_roles ? 1 : 0

  name = "${var.prefix}-cicd-apply-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = var.tags
}

# apply 用 Permissions Boundary。
# このスタックが作成する IAM Role/User に必ず付与し、特権昇格 (Allow="*"/PassRole 抜け道) を遮断する。
resource "aws_iam_policy" "cicd_apply_boundary" {
  count = var.create_cicd_roles ? 1 : 0

  name        = "${var.prefix}-cicd-apply-boundary"
  description = "Permissions boundary for IAM principals managed by this stack. Blocks privilege escalation."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedStackServices"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "rds-data:*",
          "s3:*",
          "ecs:*",
          "ecr:Get*",
          "ecr:BatchGet*",
          "ecr:Describe*",
          "ecr:List*",
          "route53:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "application-autoscaling:*",
          "logs:*",
          "cloudwatch:*",
          "sns:*",
          "ce:*",
          "ssm:Get*",
          "ssm:Describe*",
          "ssm:List*",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "secretsmanager:Get*",
          "secretsmanager:Describe*",
          "secretsmanager:List*",
          "kms:Decrypt",
          "kms:Describe*",
          "kms:GenerateDataKey*",
          "kms:List*",
          "iam:Get*",
          "iam:List*",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:CreateServiceLinkedRole",
          "sts:GetCallerIdentity",
          "sts:DecodeAuthorizationMessage",
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyPrivilegeEscalation"
        Effect   = "Deny"
        Resource = "*"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:DeleteUser",
          "iam:CreateLoginProfile",
          "iam:UpdateLoginProfile",
          "iam:DeleteLoginProfile",
          "iam:CreateOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:DeleteOpenIDConnectProvider",
          "iam:CreateSAMLProvider",
          "iam:UpdateSAMLProvider",
          "iam:DeleteSAMLProvider",
          "iam:AttachUserPolicy",
          "iam:PutUserPolicy",
        ]
      },
      {
        Sid      = "DenyDestructiveAndAuditDisable"
        Effect   = "Deny"
        Resource = "*"
        Action = [
          "iam:DeleteRole",
          "iam:DeleteRolePermissionsBoundary",
          "kms:ScheduleKeyDeletion",
          "kms:DisableKey",
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "rds:DeleteDBCluster",
          "rds:DeleteDBInstance",
          "rds:ModifyDBClusterSnapshotAttribute",
          "secretsmanager:DeleteSecret",
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:PutEventSelectors",
          "config:DeleteConfigRule",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "securityhub:DisableSecurityHub",
        ]
      },
      {
        Sid      = "DenyOrganizationAndAccount"
        Effect   = "Deny"
        Resource = "*"
        Action = [
          "organizations:*",
          "account:*",
          "billing:*",
          "aws-portal:*",
        ]
      },
      {
        Sid    = "RequireBoundaryOnNewIamPrincipals"
        Effect = "Deny"
        Action = [
          "iam:CreateRole",
          "iam:PutRolePermissionsBoundary",
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "iam:PermissionsBoundary" = "arn:aws:iam::${var.aws_account_id}:policy/${var.prefix}-cicd-apply-boundary"
          }
        }
      },
    ]
  })

  tags = var.tags
}

# apply 用の権限は環境別最小限。実装は別ファイルで管理推奨。
# 重要: Action="*" は禁止。スタックが実際に管理するサービスのみ Allow し、
#       Deny ブロックで特権昇格と監査無効化を多層的に防ぐ。
resource "aws_iam_role_policy" "cicd_apply_min" {
  count = var.create_cicd_roles ? 1 : 0

  name = "${var.prefix}-cicd-apply-min-policy"
  role = aws_iam_role.cicd_apply[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedStackServices"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "rds-data:*",
          "s3:*",
          "ecs:*",
          "ecr:Get*",
          "ecr:BatchGet*",
          "ecr:Describe*",
          "ecr:List*",
          "route53:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "application-autoscaling:*",
          "logs:*",
          "cloudwatch:*",
          "sns:*",
          "ce:*",
          "ssm:Get*",
          "ssm:Describe*",
          "ssm:List*",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "secretsmanager:Get*",
          "secretsmanager:Describe*",
          "secretsmanager:List*",
          "kms:Decrypt",
          "kms:Describe*",
          "kms:GenerateDataKey*",
          "kms:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowIamForStackResources"
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "iam:CreateRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:CreateServiceLinkedRole",
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.prefix}-*",
          "arn:aws:iam::${var.aws_account_id}:policy/${var.prefix}-*",
          "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/*",
        ]
      },
      {
        Sid      = "AllowPassRoleForStackOnly"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${var.aws_account_id}:role/${var.prefix}-*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "ecs-tasks.amazonaws.com",
              "monitoring.rds.amazonaws.com",
              "rds.amazonaws.com",
              "ec2.amazonaws.com",
              "lambda.amazonaws.com",
              "events.amazonaws.com",
            ]
          }
        }
      },
      {
        Sid      = "RequireBoundaryOnRoleCreate"
        Effect   = "Deny"
        Action   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "iam:PermissionsBoundary" = aws_iam_policy.cicd_apply_boundary[0].arn
          }
        }
      },
      {
        Sid      = "DenyDestructiveAndAuditDisable"
        Effect   = "Deny"
        Resource = "*"
        Action = [
          "iam:DeleteRole",
          "iam:DeleteUser",
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:CreateLoginProfile",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:CreateSAMLProvider",
          "iam:DeleteRolePermissionsBoundary",
          "kms:ScheduleKeyDeletion",
          "kms:DisableKey",
          "s3:DeleteBucket",
          "rds:DeleteDBCluster",
          "rds:DeleteDBInstance",
          "secretsmanager:DeleteSecret",
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "config:DeleteConfigRule",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "securityhub:DisableSecurityHub",
          "organizations:*",
          "account:*",
          "billing:*",
          "aws-portal:*",
        ]
      },
    ]
  })
}
