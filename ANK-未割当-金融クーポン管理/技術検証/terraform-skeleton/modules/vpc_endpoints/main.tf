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
# VPC Endpoints (AWS PrivateLink) モジュール
#
# FISC 第11版 / FSI Lens for FISC: 「金融データを公衆インターネット経由で
# 流通させない」要件を満たすため、AWS API への通信は VPC Endpoint で
# プライベート閉域に限定する。
#
# - Gateway endpoint: S3, DynamoDB (無料)
# - Interface endpoint: KMS, SecretsManager, STS, Logs, ECR (api/dkr),
#                       Monitoring, SSM (3種), ElastiCache, SQS, SNS,
#                       SecurityHub, GuardDuty, Config 等 (時間+データ課金)
#
# 全 endpoint に対して private DNS 有効 + endpoint SG で 443 のみ許可。
# =============================================================================

# Gateway endpoint: S3
resource "aws_vpc_endpoint" "s3_gateway" {
  count = var.enable_s3_gateway ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowAllWithinOrgOrAccount"
      Effect    = "Allow"
      Principal = "*"
      Action    = "*"
      Resource  = "*"
      Condition = var.org_id != null ? {
        StringEquals = { "aws:PrincipalOrgID" = var.org_id }
        } : {
        StringEquals = { "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.prefix}-vpce-s3" })
}

# Gateway endpoint: DynamoDB (Terraform state lock + 一般用途)
resource "aws_vpc_endpoint" "dynamodb_gateway" {
  count = var.enable_dynamodb_gateway ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.tags, { Name = "${var.prefix}-vpce-dynamodb" })
}

# Interface endpoint 用の共通 SG (443 inbound from VPC CIDR)
resource "aws_security_group" "interface" {
  count = length(var.interface_endpoint_services) > 0 ? 1 : 0

  name        = "${var.prefix}-vpce-interface-sg"
  description = "Allow 443 from VPC CIDR to AWS Interface Endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Egress to anywhere (response traffic)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.prefix}-vpce-interface-sg" })
}

# Interface endpoints (for each)
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoint_services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.interface[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.prefix}-vpce-${each.value}" })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
