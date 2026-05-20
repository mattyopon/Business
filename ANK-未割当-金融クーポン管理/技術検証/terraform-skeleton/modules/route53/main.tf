terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

# Private Hosted Zone (内部サービス間通信用)
resource "aws_route53_zone" "private" {
  count = var.create_private_zone ? 1 : 0

  name = var.private_zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = var.tags
}

# Public Hosted Zone (顧客チャネル向け API、要件次第)
resource "aws_route53_zone" "public" {
  count = var.create_public_zone ? 1 : 0

  name = var.public_zone_name

  tags = var.tags
}
