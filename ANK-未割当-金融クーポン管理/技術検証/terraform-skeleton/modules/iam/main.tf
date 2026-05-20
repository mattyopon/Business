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

# apply 用の権限は環境別最小限。実装は別ファイルで管理推奨。
# 例として PowerUser + IAM 制限を付与 (本番では環境別に最小化)
resource "aws_iam_role_policy" "cicd_apply_min" {
  count = var.create_cicd_roles ? 1 : 0

  name = "${var.prefix}-cicd-apply-min-policy"
  role = aws_iam_role.cicd_apply[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      # 重要: 以下を明示的に Deny する (例)
      {
        Effect = "Deny"
        Action = [
          "iam:DeleteRole",
          "iam:DeleteUser",
          "kms:ScheduleKeyDeletion",
          "s3:DeleteBucket",  # PROD では特に保護
        ]
        Resource = "*"
      }
    ]
  })
}
