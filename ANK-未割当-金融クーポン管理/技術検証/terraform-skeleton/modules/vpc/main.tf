data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  app_subnet_cidrs    = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  db_subnet_cidrs     = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
  batch_subnet_cidrs  = var.create_isolated_batch_subnet ? [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 12)] : []
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private_app" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.app_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-app-${count.index + 1}"
    Tier = "private-app"
  })
}

resource "aws_subnet" "private_db" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.db_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-db-${count.index + 1}"
    Tier = "private-db"
  })
}

resource "aws_subnet" "isolated_batch" {
  count             = var.create_isolated_batch_subnet ? var.az_count : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.batch_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.prefix}-isolated-batch-${count.index + 1}"
    Tier = "isolated-batch"
  })
}

# Internet Gateway / NAT Gateway 等は PF 側集中管理想定のため、create_nat_gateway = true 時のみ作成
resource "aws_internet_gateway" "this" {
  count  = var.create_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-igw"
  })
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.prefix}/flow-log"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "flow_logs" {
  count      = var.enable_flow_logs ? 1 : 0
  role       = aws_iam_role.flow_logs[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSVPCFlowLogsCloudWatchLogsRole"
}

# AWS managed policy が無い場合は inline policy を定義
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.prefix}-vpc-flow-logs-policy"
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc-flow-log"
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = merge(var.tags, {
    Name = "${var.prefix}-db-subnet-group"
  })
}
