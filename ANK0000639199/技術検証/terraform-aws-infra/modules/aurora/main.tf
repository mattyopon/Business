# =============================================================================
# Aurora MySQL Module
# =============================================================================

variable "cluster_identifier" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "8.0.mysql_aurora.3.04.0"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "database_name" {
  type = string
}

variable "master_username" {
  type    = string
  default = "admin"
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "allowed_security_groups" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

# =============================================================================
# Random Password
# =============================================================================

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =============================================================================
# Secrets Manager
# =============================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.cluster_identifier}-credentials"
  description = "Aurora MySQL credentials for ${var.cluster_identifier}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
  })
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "aurora" {
  name        = "${var.cluster_identifier}-sg"
  description = "Security group for Aurora MySQL"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-sg"
  })
}

resource "aws_security_group_rule" "aurora_ingress" {
  count = length(var.allowed_security_groups)

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.aurora.id
}

resource "aws_security_group_rule" "aurora_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.aurora.id
}

# =============================================================================
# Subnet Group
# =============================================================================

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.cluster_identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-subnet-group"
  })
}

# =============================================================================
# Parameter Group
# =============================================================================

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${var.cluster_identifier}-cluster-params"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL cluster parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Tokyo"
  }

  tags = var.tags
}

# =============================================================================
# Aurora Cluster
# =============================================================================

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = var.cluster_identifier
  engine             = "aurora-mysql"
  engine_version     = var.engine_version
  engine_mode        = "provisioned"

  database_name   = var.database_name
  master_username = var.master_username
  master_password = random_password.master.result

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  storage_encrypted = var.storage_encrypted

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"

  skip_final_snapshot = true

  tags = var.tags
}

# =============================================================================
# Aurora Instances
# =============================================================================

resource "aws_rds_cluster_instance" "aurora" {
  count = var.instance_count

  identifier         = "${var.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  publicly_accessible = false

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-${count.index + 1}"
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.aurora.reader_endpoint
}

output "cluster_id" {
  value = aws_rds_cluster.aurora.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
