# Terraform GCP Infrastructure

金融決済プラットフォーム向けGCPインフラのIaCデモです。

## 構成

```
terraform-gcp/
├── README.md
├── main.tf              # メインリソース定義
├── variables.tf         # 変数定義
├── outputs.tf          # 出力定義
├── providers.tf        # プロバイダー設定
└── modules/
    ├── gke/            # GKEクラスター
    ├── cloudsql/       # Cloud SQL
    └── networking/     # VPCネットワーク
```

## 構築するリソース

### ネットワーク
- VPC
- サブネット（Public/Private）
- Cloud NAT
- Cloud Armor（WAF）

### コンピューティング
- GKEクラスター
- Node Pool（オートスケーリング）

### データベース
- Cloud SQL（PostgreSQL）
- Memorystore（Redis）

### セキュリティ
- IAM
- Secret Manager
- Cloud KMS

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
