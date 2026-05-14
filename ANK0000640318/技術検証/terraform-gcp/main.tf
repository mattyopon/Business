# ==============================================
# GCP Infrastructure for Financial Platform
# ==============================================

# ----------------------------------------------
# VPC Network
# ----------------------------------------------
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Public Subnet
resource "google_compute_subnetwork" "public" {
  name          = "${var.project_name}-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id
}

# Private Subnet
resource "google_compute_subnetwork" "private" {
  name          = "${var.project_name}-private-subnet"
  ip_cidr_range = "10.0.10.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# Cloud NAT
resource "google_compute_router" "main" {
  name    = "${var.project_name}-router"
  region  = var.region
  network = google_compute_network.main.id
  project = var.project_id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.project_name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ----------------------------------------------
# GKE Cluster (Autopilot mode)
# 参画用/運用ドキュメント/01_インフラ設計書.md と整合させるため Autopilot 構成にする。
# Autopilot は Google がノード管理 (容量・OS・パッチ・スケール) を行うため、
# node_pool / shielded_instance_config / autoscaling 等は不要 (Autopilot 自体に内蔵)。
# ----------------------------------------------
resource "google_container_cluster" "main" {
  name             = "${var.project_name}-gke"
  location         = var.region
  project          = var.project_id
  enable_autopilot = true

  # VPC設定
  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.private.name

  # プライベートクラスター
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # IPアロケーション
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Master Authorized Networks (運用元 / 踏み台 / IAP から)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/8"
      display_name = "internal-ops"
    }
  }

  # リリースチャンネル (Autopilot は REGULAR/STABLE が選べる)
  release_channel {
    channel = "REGULAR"
  }
}

# ----------------------------------------------
# Cloud SQL (PostgreSQL)
# ----------------------------------------------
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  settings {
    tier              = "db-custom-2-4096"
    availability_type = "REGIONAL"  # 高可用性

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      location                       = var.region
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    maintenance_window {
      day          = 7  # Sunday
      hour         = 3
      update_track = "stable"
    }
  }

  deletion_protection = true
}

# ----------------------------------------------
# Memorystore (Redis)
# ----------------------------------------------
resource "google_redis_instance" "main" {
  name           = "${var.project_name}-redis"
  tier           = "STANDARD_HA"
  memory_size_gb = 5
  region         = var.region
  project        = var.project_id

  authorized_network = google_compute_network.main.id

  redis_version = "REDIS_7_0"

  transit_encryption_mode = "SERVER_AUTHENTICATION"
}

# ----------------------------------------------
# Cloud Armor (WAF / DDoS) - 設計書 01_インフラ設計書.md "6.1 Cloud Armor" と整合
# ----------------------------------------------
resource "google_compute_security_policy" "main" {
  name        = "${var.project_name}-armor"
  project     = var.project_id
  description = "Cloud Armor policy for payment platform"

  # OWASP マネージドルール (XSS / SQLi)
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block SQL injection"
  }

  # Rate-based (1分1000reqまで)
  rule {
    action   = "rate_based_ban"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 1000
        interval_sec = 60
      }
      conform_action = "allow"
      exceed_action  = "deny(429)"
      ban_duration_sec = 600
    }
    description = "Rate limit per source IP"
  }

  # デフォルトルール
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }
}

# ----------------------------------------------
# Cloud Spanner - 設計書 01_インフラ設計書.md "5.2 Cloud Spanner" と整合
#   regional 構成 = 単一リージョン強整合 (グローバル分散ではない点に注意)
# ----------------------------------------------
resource "google_spanner_instance" "main" {
  name             = "${var.project_name}-spanner"
  display_name     = "${var.project_name}-spanner"
  config           = "regional-${var.region}"
  processing_units = 1000  # 1 node 相当
  project          = var.project_id

  labels = {
    env       = var.environment
    workload  = "payment"
    managedby = "terraform"
  }
}

resource "google_spanner_database" "payment" {
  instance                 = google_spanner_instance.main.name
  name                     = "payment"
  project                  = var.project_id
  version_retention_period = "7d"
  deletion_protection      = true
}
