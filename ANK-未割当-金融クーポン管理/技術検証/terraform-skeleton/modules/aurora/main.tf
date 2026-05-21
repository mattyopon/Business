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

  # FISC 第11版 / 金融庁 サイバーセキュリティGL / PCI-DSS v4.0 の監査ログ要件対応。
  # pgAudit で SQL 実行を行レベルで記録 (出典: AWS Docs pgAudit on Aurora PostgreSQL)。
  parameter {
    name         = "shared_preload_libraries"
    value        = "pgaudit"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pgaudit.role"
    value = "rds_pgaudit"
  }

  parameter {
    # 監査対象: DDL (テーブル定義変更) + WRITE (UPDATE/INSERT/DELETE/COPY) + ROLE (権限変更)。
    # READ も含めると I/O が劇増するため、必要に応じて env で上書き可能。
    name  = "pgaudit.log"
    value = var.pgaudit_log_classes
  }

  parameter {
    name  = "pgaudit.log_parameter"
    value = "1"
  }

  parameter {
    name  = "pgaudit.log_statement_once"
    value = "1"
  }

  tags = var.tags
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.prefix}-aurora-db-pg"
  family      = var.cluster_parameter_group_family
  description = "DB parameter group for ${var.prefix} Aurora"

  tags = var.tags
}

# =============================================================================
# Aurora Global Database (cross-region DR)
#
# FISC 5.1 / FSI Lens Reliability / 金融庁 GL BCP 要件:
# - 単一 region 障害でもサービス継続可能 (RPO < 1秒、RTO < 1分)
# - 同期 (sync) ではなく storage-level async レプリケーション
#
# 設計:
# - global_cluster は primary region 側で作成 (本モジュール)
# - secondary region cluster は env 側で別 provider alias で
#   別 modules/aurora インスタンスを使うか、aws_rds_cluster を直接定義
# - global_cluster_identifier を共有
# - secondary cluster は replication_source_identifier に primary ARN
# - 注意: primary 削除前に secondary を detach する手順が必要 (運用 runbook 必須)
# =============================================================================
resource "aws_rds_global_cluster" "this" {
  count = var.enable_global_database ? 1 : 0

  global_cluster_identifier = "${var.prefix}-aurora-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  database_name             = var.database_name
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  # source_db_cluster_identifier は使わない (本 cluster を初回作成として global に登録)。
  # 既存 cluster を global にする場合は source_db_cluster_identifier を指定する。

  # Codex P1 (2026-05-20): 旧設計では engine_version を ignore していたが、
  # それだと global cluster 経由でも security patch upgrade を Terraform で当てられないため除去。
  # 運用上: aws が microversion を auto-apply した場合、次回 plan で drift が出るので
  # var.engine_version を最新値に揃えてから apply するか `terraform plan -refresh-only` で吸収する。
}

# =============================================================================
# Aurora cluster (Codex P1 対応 / 2026-05-20)
#
# engine_version の ignore_changes は **global cluster 配下の primary だけに限定**。
# 理由: ignore_changes を無条件で付けると、global を使わない通常クラスタでも
#   var.engine_version を変えても Terraform が反映しない状態になり、
#   セキュリティパッチ含む engine upgrade を運用で当てられなくなる (Codex P1)。
# 対応:
#   - var.enable_global_database = false → aws_rds_cluster.standalone (engine_version は ignore しない)
#   - var.enable_global_database = true  → aws_rds_cluster.global_primary (engine_version は ignore する)
#   両者は属性的にほぼ同一だが、lifecycle.ignore_changes はリテラルしか書けないため
#   Terraform の制約上 2 resource に分離するしかない (HCL 仕様)。
# 下流参照は locals.cluster_* に集約し、消費側は分岐を意識しなくて済む。
#
# Codex P1 (2026-05-20 2nd review): state migration の moved block を追加。
#   既存 state で aws_rds_cluster.this を使っていた deployment は、enable_global_database
#   の値に応じて自動的に standalone[0] / global_primary[0] へ move される。
#   両 moved block の destination は count 切替により片方しか存在しないため、Terraform は
#   存在する方の destination だけ rename を実行する (no-op になる方は安全に無視)。
#
# Codex P1 4th review 対応 (2026-05-20): cluster_identifier 差別化により、
#   - standalone: ${prefix}-aurora-cluster (旧 aws_rds_cluster.this と同一名)
#   - global_primary: ${prefix}-aurora-cluster-global (新規・別 AWS リソース)
# としたことで、enable_global_database 切替時の AWS 側衝突が物理的に発生しない。
#
# 既存 state migration 互換性:
#   - 旧 module を enable_global_database=false で利用中 → moved block で
#     aws_rds_cluster.this → aws_rds_cluster.standalone[0] へ in-place 移行 ✓
#   - 旧 module を enable_global_database=true で利用中 → そもそも旧 module には
#     global cluster サポートが無かった (この新 module が初導入) ため、該当 state は
#     存在しない。よって global 用 moved block 不要 ✓
#
# 注: Terraform は同一 from を持つ moved を 2 つ書けない (duplicate move error)。
#   今回は cluster_identifier 差別化で global 側は新規作成扱いとなるため、moved は
#   standalone[0] への 1 本のみで論理的に充足。
# =============================================================================

moved {
  from = aws_rds_cluster.this
  to   = aws_rds_cluster.standalone[0]
}

resource "aws_rds_cluster" "standalone" {
  count = var.enable_global_database ? 0 : 1

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

  # postgresql ログを CloudWatch Logs に出力。pgAudit の出力もこれに乗る。
  # CloudWatch Logs から Subscription Filter で S3 (Object Lock COMPLIANCE 7年) に転送する想定。
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  iam_database_authentication_enabled = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  lifecycle {
    # engine_version は ignore しない: standalone は Terraform が engine_version を完全管理
    ignore_changes = [
      master_username,
      final_snapshot_identifier,
    ]
  }

  tags = var.tags
}

resource "aws_rds_cluster" "global_primary" {
  count = var.enable_global_database ? 1 : 0

  # Codex P1 4th review 対応 (2026-05-20): cluster_identifier に `-global` suffix を付与し、
  # standalone (`${prefix}-aurora-cluster`) と物理的に別 AWS リソースとして分離。
  # これで enable_global_database を後から true⇔false 切替する際の AWS 側名前衝突
  # (両 resource が同一名で create を試みる) を回避する。
  # ※ 後付け global 化は AWS Aurora Global Database の仕様上 in-place adoption 不可で、
  #   primary を新規 cluster として作成 + 旧 standalone から手動で snapshot restore +
  #   グローバルクラスタアタッチが必須。これは Terraform の制約ではなく AWS の制約。
  #   skeleton としてはコード上の安全側に倒し、後付け切替は別運用 (snapshot 経由 DR) で行う前提。
  cluster_identifier            = "${var.prefix}-aurora-cluster-global"
  engine                        = "aurora-postgresql"
  engine_version                = var.engine_version
  database_name                 = var.database_name
  master_username               = var.master_username
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  # Aurora Global Database 連携: global cluster の primary cluster としてアタッチ
  global_cluster_identifier = aws_rds_global_cluster.this[0].id

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

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
    # global cluster 配下の primary は engine_version 変更が global 側 microversion で発生し drift する。
    # 運用上 engine upgrade は aws_rds_global_cluster.this.engine_version を変更して適用する。
    ignore_changes = [
      master_username,
      final_snapshot_identifier,
      engine_version,
    ]
  }

  tags = var.tags
}

# 下流参照集約: enable_global_database による分岐を1箇所に閉じ込める
locals {
  cluster_id                 = var.enable_global_database ? aws_rds_cluster.global_primary[0].id : aws_rds_cluster.standalone[0].id
  cluster_identifier         = var.enable_global_database ? aws_rds_cluster.global_primary[0].cluster_identifier : aws_rds_cluster.standalone[0].cluster_identifier
  cluster_engine             = var.enable_global_database ? aws_rds_cluster.global_primary[0].engine : aws_rds_cluster.standalone[0].engine
  cluster_engine_version     = var.enable_global_database ? aws_rds_cluster.global_primary[0].engine_version : aws_rds_cluster.standalone[0].engine_version
  cluster_endpoint           = var.enable_global_database ? aws_rds_cluster.global_primary[0].endpoint : aws_rds_cluster.standalone[0].endpoint
  cluster_reader_endpoint    = var.enable_global_database ? aws_rds_cluster.global_primary[0].reader_endpoint : aws_rds_cluster.standalone[0].reader_endpoint
  cluster_port               = var.enable_global_database ? aws_rds_cluster.global_primary[0].port : aws_rds_cluster.standalone[0].port
  cluster_arn                = var.enable_global_database ? aws_rds_cluster.global_primary[0].arn : aws_rds_cluster.standalone[0].arn
  cluster_resource_id        = var.enable_global_database ? aws_rds_cluster.global_primary[0].cluster_resource_id : aws_rds_cluster.standalone[0].cluster_resource_id
  cluster_master_user_secret = var.enable_global_database ? aws_rds_cluster.global_primary[0].master_user_secret : aws_rds_cluster.standalone[0].master_user_secret
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.prefix}-aurora-${count.index + 1}"
  cluster_identifier = local.cluster_id
  instance_class     = var.instance_class
  engine             = local.cluster_engine
  engine_version     = local.cluster_engine_version

  db_parameter_group_name = aws_db_parameter_group.this.name
  monitoring_interval     = var.enhanced_monitoring_interval
  monitoring_role_arn     = var.enhanced_monitoring_interval > 0 ? var.enhanced_monitoring_role_arn : null

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  auto_minor_version_upgrade = false

  tags = var.tags
}

# Database Activity Streams (RDS Activity Streams)。
# FISC 第11版 4.5 / PCI-DSS v4.0 Req10 の改竄不能監査証跡要件に対応。
# Kinesis Data Stream に同期/非同期で全 SQL を吐き、改竄を物理的に不可能化する。
resource "aws_rds_cluster_activity_stream" "this" {
  count = var.activity_stream_kms_key_arn != null ? 1 : 0

  resource_arn = local.cluster_arn
  mode         = var.activity_stream_mode # "sync" (PCI推奨) or "async"
  kms_key_id   = var.activity_stream_kms_key_arn

  depends_on = [aws_rds_cluster_instance.this]
}
