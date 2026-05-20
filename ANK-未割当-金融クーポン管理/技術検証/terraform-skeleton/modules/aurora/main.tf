terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.prefix}-aurora-cluster-pg"
  family      = var.cluster_parameter_group_family
  description = "Cluster parameter group for ${var.prefix} Aurora"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "mod"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_connections"
    value = "on"
  }

  parameter {
    name  = "log_disconnections"
    value = "on"
  }

  tags = var.tags
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.prefix}-aurora-db-pg"
  family      = var.cluster_parameter_group_family
  description = "DB parameter group for ${var.prefix} Aurora"

  tags = var.tags
}

resource "aws_rds_cluster" "this" {
  cluster_identifier            = "${var.prefix}-aurora-cluster"
  engine                        = "aurora-postgresql"
  engine_version                = var.engine_version
  database_name                 = var.database_name
  master_username               = var.master_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  storage_encrypted = true
  # 注意: Aurora の暗号化キーは作成時にしか指定できない (変更不可)
  kms_key_id = var.kms_key_arn

  db_subnet_group_name            = var.db_subnet_group_name
  vpc_security_group_ids          = var.security_group_ids
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  copy_tags_to_snapshot        = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.prefix}-final-${formatdate("YYYYMMDD-hhmmss", timestamp())}" : null

  enabled_cloudwatch_logs_exports     = ["postgresql"]
  iam_database_authentication_enabled = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  lifecycle {
    ignore_changes = [
      master_username,
      final_snapshot_identifier,
    ]
  }

  tags = var.tags
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.prefix}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  db_parameter_group_name = aws_db_parameter_group.this.name
  monitoring_interval     = var.enhanced_monitoring_interval
  monitoring_role_arn     = var.enhanced_monitoring_interval > 0 ? var.enhanced_monitoring_role_arn : null

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  auto_minor_version_upgrade = false

  tags = var.tags
}
