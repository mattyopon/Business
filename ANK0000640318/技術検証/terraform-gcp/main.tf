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

# Public Subnet (外部 LB / Cloud NAT 用)
# 重要: gke-subnet (10.0.0.0/20 = 10.0.0.0-10.0.15.255) と CIDR が重ならない範囲を選ぶ。
#       db-subnet (10.0.16.0/24) / proxy-subnet (10.0.17.0/24) も避ける必要がある。
#       本書では 10.0.32.0/24 (10.0.32.0-10.0.32.255) を採用。設計書 01_インフラ設計書.md の
#       「2.2 サブネット設計」もこの値で整合させること。
resource "google_compute_subnetwork" "public" {
  name          = "${var.project_name}-public-subnet"
  ip_cidr_range = "10.0.32.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id
}

# Private Subnet (GKE ノード用)
# 設計書 01_インフラ設計書.md 「2.2 サブネット設計」と整合: gke-subnet 10.0.0.0/20
resource "google_compute_subnetwork" "private" {
  name          = "${var.project_name}-gke-subnet"
  ip_cidr_range = "10.0.0.0/20"
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

  # Master Authorized Networks
  # 設計書 01_インフラ設計書.md 「3.x 踏み台・IAP 経由アクセス」と整合させ、
  # 10.0.0.0/8 のような広域指定は禁止。以下に限定する:
  #   - 踏み台ホストサブネット (Bastion): variables 経由で個別 CIDR を渡す
  #   - IAP TCP forwarding range (Google 管理): 35.235.240.0/20 (固定)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.bastion_cidr
      display_name = "bastion-host"
    }
    cidr_blocks {
      cidr_block   = "35.235.240.0/20"
      display_name = "google-iap-tcp-forwarding"
    }
  }

  # Binary Authorization (設計書 01_インフラ設計書.md 「4.1 GKE Autopilot」と整合)
  # 信頼できるコンテナイメージのみ deploy を許可するため、プロジェクト既定ポリシーを強制
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # リリースチャンネル (Autopilot は REGULAR/STABLE が選べる)
  release_channel {
    channel = "REGULAR"
  }
}

# ----------------------------------------------
# Cloud SQL (PostgreSQL)
# 設計書 01_インフラ設計書.md 7.3 「バックアップ戦略」と整合させ、30日保持に設定する。
# private_network に VPC を直接指定するため、事前に Private Service Access (Service Networking) を確立する必要がある。
# ----------------------------------------------
resource "google_compute_global_address" "private_service_access" {
  name          = "${var.project_name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
}

resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-custom-4-16384" # 設計書 5.1 と整合 (4 vCPU / 16GB RAM)
    availability_type = "REGIONAL"          # 高可用性

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      location                       = var.region
      backup_retention_settings {
        retained_backups = 30 # 設計書 7.3 と整合 (30日保持)
      }
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
      day          = 7 # Sunday
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
#
# 重要: Cloud Armor の security_policy は **単独では何も保護しない**。
#       backend_service / backend_bucket / global external Application Load Balancer の
#       backend に `security_policy = google_compute_security_policy.main.id` を紐付けて
#       初めてトラフィックが評価される。
#       本 main.tf は backend_service を含まない最小デモ構成のため、policy 単体だけを作る。
#       実環境では Cloud Armor を効かせる対象 (GLB 配下の backend service / NEG) で
#       下記のような attachment ブロックを追加すること:
#
#         resource "google_compute_backend_service" "payment_api" {
#           name            = "payment-api-bs"
#           project         = var.project_id
#           security_policy = google_compute_security_policy.main.id  # ← これがないと Cloud Armor は無効
#           # backend / health_checks / load_balancing_scheme = "EXTERNAL_MANAGED" 等
#         }
#
#       attachment 例は backend_service_attachment_example.tf.example として
#       (本ファイルとは別に) サンプル提示する想定。本ファイルでは backend を作らない。
# ----------------------------------------------
resource "google_compute_security_policy" "main" {
  name        = "${var.project_name}-armor"
  project     = var.project_id
  description = "Cloud Armor policy TEMPLATE (must be attached to a backend_service to take effect; see comments above)"

  # OWASP マネージドルール (XSS / SQLi)
  # 2026 時点の Cloud Armor 公式仕様では `evaluatePreconfiguredWaf` (versioned ruleset) を使う。
  # 旧 `evaluatePreconfiguredExpr('xss-stable')` は legacy 扱いで、policy 作成時に reject される。
  # ルールセット名はバージョン suffix を含む必要がある (例: xss-v33-stable / sqli-v33-stable)。
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Block XSS attacks (Cloud Armor preconfigured WAF v3.3, sensitivity 1)"
  }

  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})"
      }
    }
    description = "Block SQL injection (Cloud Armor preconfigured WAF v3.3, sensitivity 1)"
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
      conform_action   = "allow"
      exceed_action    = "deny(429)"
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
  processing_units = 3000 # 3 node 相当 (設計書 5.2 と整合: ノード数 3)
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
