# Terraform AWS インフラ構築デモ

医療IT案件向けのAWSインフラをTerraformでコード化したデモです。

## 概要

本デモは、医療系AIプロダクトの本番環境を想定したAWSインフラをTerraformで構築します。

### 構築するリソース (本リポ同梱の実装範囲)

- **ネットワーク**: VPC、サブネット（パブリック/プライベート）、NAT Gateway (`modules/vpc/`)
- **コンピューティング**: EKS クラスター、Fargate プロファイル (`modules/eks/`)
- **データベース**: Aurora MySQL (マルチAZ) (`modules/aurora/`)

### 同梱外 (案件参画時に追加実装)

- **ストレージ**: S3 (モデル保存) / EFS (共有ストレージ) — モジュール未同梱
- **セキュリティ**: WAF / 追加のセキュリティグループ / 追加 IAM ロール (Web ACL の関連付けや FGAC 設計は本リポ外)
- **監視**: CloudWatch アラーム / SNS Topic — モジュール未同梱
- **prod 環境**: `environments/dev/` のみ同梱 (prod はテンプレ流用で派生する想定)
- **アーキテクチャドキュメント (`docs/architecture.md`)**: 未同梱 (参画用 `01_AWSインフラ設計書.md` を一次資料とする)

## ディレクトリ構成 (本リポ同梱の実体)

```
terraform-aws-infra/
├── README.md
├── environments/
│   └── dev/
│       └── main.tf
└── modules/
    ├── vpc/
    ├── eks/
    └── aurora/
```

## クイックスタート

```bash
# 1. 初期化
cd environments/dev
terraform init

# 2. プラン確認
terraform plan

# 3. 適用（実際には実行しない - デモ用）
# terraform apply
```

## モジュール説明

### VPC モジュール
- マルチAZ構成（3AZ）
- パブリック/プライベートサブネット分離
- NAT Gateway（冗長化）
- VPCフローログ有効化

### EKS モジュール
- Kubernetes 1.33 (2026-05時点の EKS 標準サポート対象。アップグレード方針: 公式リリースから 6ヶ月以内に検証環境で n+1 を試験、本番は四半期ごとに段階移行)
- Fargate プロファイル（サーバーレス）
- OIDC プロバイダー（IAM連携）
- クラスターログ有効化

### Aurora モジュール
- MySQL 8.0 互換
- マルチAZ自動フェイルオーバー
- 暗号化有効（KMS）
- 自動バックアップ（7日保持）

## セキュリティ考慮事項

医療データを扱うため、以下を実装:

- **暗号化**: 保存時・転送時の暗号化（KMS、TLS）
- **アクセス制御**: 最小権限IAMポリシー
- **監査**: CloudTrail、VPCフローログ
- **ネットワーク分離**: プライベートサブネット配置

## 参考資料

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
