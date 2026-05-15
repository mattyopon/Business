# Terraform GCP Infrastructure

金融決済プラットフォーム向けGCPインフラのIaCデモです。

## 構成 (本リポ同梱の実体)

```
terraform-gcp/
├── README.md
├── main.tf              # VPC / GKE Autopilot / Cloud SQL / Memorystore / Cloud Armor / Cloud Spanner
├── variables.tf         # 変数定義
└── providers.tf         # プロバイダー設定
```

> 本デモは **single-file 構成** で書かれており、`outputs.tf` / `modules/` / `environments/` は同梱していません。新規案件で本テンプレを流用する際に、必要な粒度でモジュール化してください。

## 構築するリソース (`main.tf` で実装済み)

### ネットワーク
- VPC (`google_compute_network`)
- Private サブネット (`google_compute_subnetwork`)
- Cloud Armor (`google_compute_security_policy`) — XSS / SQLi / Rate-limit ルール
- (Cloud NAT は本デモには未実装。必要に応じて追加してください)

### コンピューティング
- **GKE Autopilot クラスター** (`google_container_cluster` with `enable_autopilot=true`)
- ノードプールは Autopilot が自動管理 (`google_container_node_pool` リソースは存在しません)

### データベース / キャッシュ
- Cloud SQL (PostgreSQL 15, Regional 構成)
- Memorystore (Redis 7.0, Standard HA)
- Cloud Spanner (regional 構成、processing_units=1000、`payment` データベース) — `01_インフラ設計書.md` の Spanner 設計と整合

### セキュリティ
- IAM (本デモには明示的なロール定義なし。Workload Identity Federation 設定は別途整備)
- (Secret Manager / Cloud KMS は本デモには未実装。本格運用では追加が必須)

## 使用方法

```bash
# 初期化
terraform init

# プラン確認
terraform plan

# 適用
terraform apply

# 破棄
terraform destroy
```

## 環境変数

```bash
export GOOGLE_PROJECT="your-project-id"
export GOOGLE_REGION="asia-northeast1"
```

## ベストプラクティス

1. **状態管理**: GCSバックエンドの使用
2. **ワークスペース**: 環境別の分離
3. **モジュール化**: 再利用可能なモジュール設計
4. **セキュリティ**: シークレットの外部管理
