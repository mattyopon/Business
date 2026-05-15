# =============================================================================
# Providers
# =============================================================================

terraform {
  # Terraform 1.9 で input variable validation の condition から
  # 他の variable / data source / local を参照可能になった (cross-variable
  # validation)。modules/vpc/variables.tf の `enable_nat_gateway` 周辺で
  # `var.public_subnets` / `var.single_nat_gateway` を参照するためには
  # 1.9 以降が必要。1.0-1.8 では `init` / `validate` 段階で
  # "Invalid reference in variable validation" となり plan 不可。
  # 参考: https://www.hashicorp.com/blog/terraform-1-9-enhances-input-variable-validations
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration (uncomment for production use)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "search-system/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
