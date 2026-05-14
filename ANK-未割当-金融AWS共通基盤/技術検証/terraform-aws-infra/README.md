# Terraform AWS インフラ構築デモ (金融AWS共通基盤 案件配下)

汎用 AWS インフラ (VPC + EKS + Aurora) を Terraform でコード化したサンプルです。本案件 (金融AWS共通基盤) の参考デモとして、ANK0000639199 (医療MLOps) から流用したコード構造をベースにしており、**金融機関特有の Landing Zone / Organizations / FISC 要件 / Direct Connect は本デモには含まれていません**。

## 概要

本デモは、金融AWS共通基盤を構築する際のベース構造 (VPC + EKS + Aurora MySQL) を Terraform でコード化した雛形です。金融機関固有要件 (LZA / Control Tower / FISC 安全対策基準 / マルチアカウント SCP / Direct Connect) は別途追加実装が必要です。

### 構築するリソース

- **ネットワーク**: VPC、サブネット（パブリック/プライベート）、NAT Gateway
- **コンピューティング**: EKS クラスター、Fargate プロファイル
- **データベース**: Aurora MySQL（マルチAZ）
- **ストレージ**: S3（モデル保存用）、EFS（共有ストレージ）
- **セキュリティ**: WAF、セキュリティグループ、IAMロール
- **監視**: CloudWatch、SNS アラート

## ディレクトリ構成

```
terraform-aws-infra/
├── README.md
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── aurora/
│   ├── s3/
│   └── monitoring/
└── docs/
    └── architecture.md
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
- Kubernetes 1.33 (2026-05 時点 EKS 標準サポート対象)
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
