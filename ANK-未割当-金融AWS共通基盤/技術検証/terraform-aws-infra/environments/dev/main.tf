# =============================================================================
# Medical AI Platform - Development Environment
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 本番ではS3バックエンドを使用
  # backend "s3" {
  #   bucket         = "medical-ai-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# =============================================================================
# Local Variables
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# VPC Module
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true  # 開発環境ではコスト削減のため1つ

  enable_flow_logs     = true

  tags = local.common_tags
}

# =============================================================================
# EKS Module
# =============================================================================

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = "1.28"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  # Fargate Profile
  fargate_profiles = {
    default = {
      selectors = [
        { namespace = "default" },
        { namespace = "kube-system" }
      ]
    }
    mlops = {
      selectors = [
        { namespace = "mlops" }
      ]
    }
  }

  # クラスターログ
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator"
  ]

  tags = local.common_tags
}

# =============================================================================
# Aurora Module
# =============================================================================

module "aurora" {
  source = "../../modules/aurora"

  cluster_identifier = "${local.name_prefix}-aurora"
  engine_version     = "8.0.mysql_aurora.3.04.0"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  instance_class     = "db.t3.medium"  # 開発環境用
  instance_count     = 1               # 開発環境は1台

  database_name      = "medical_ai"
  master_username    = "admin"

  # 暗号化
  storage_encrypted  = true

  # バックアップ
  backup_retention_period = 7

  # セキュリティ
  allowed_security_groups = [module.eks.cluster_security_group_id]

  tags = local.common_tags
}

# =============================================================================
# S3 Bucket (MLモデル保存用)
# =============================================================================

resource "aws_s3_bucket" "ml_models" {
  bucket = "${local.name_prefix}-ml-models"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ml-models"
  })
}

resource "aws_s3_bucket_versioning" "ml_models" {
  bucket = aws_s3_bucket.ml_models.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_models" {
  bucket = aws_s3_bucket.ml_models.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ml_models" {
  bucket = aws_s3_bucket.ml_models.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.aurora.cluster_endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket for ML models"
  value       = aws_s3_bucket.ml_models.id
}
