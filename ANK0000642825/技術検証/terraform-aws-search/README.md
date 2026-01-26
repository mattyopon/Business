# Terraform AWS Search Infrastructure

AWSで検索システムインフラを構築するTerraformコードです。

## アーキテクチャ

```
                    ┌─────────────────┐
                    │   CloudFront    │
                    │      (CDN)      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   API Gateway   │
                    │   (REST API)    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼────────┐     │     ┌────────▼────────┐
     │     Lambda      │     │     │     Lambda      │
     │  (Search API)   │     │     │  (Index API)    │
     └────────┬────────┘     │     └────────┬────────┘
              │              │              │
              │     ┌────────▼────────┐     │
              └─────►   OpenSearch    ◄─────┘
                    │    Service      │
                    └─────────────────┘
                             │
                    ┌────────▼────────┐
                    │    Cognito      │
                    │  (認証/認可)    │
                    └─────────────────┘
```

## ディレクトリ構成

```
terraform-aws-search/
├── main.tf           # メインリソース定義
├── variables.tf      # 変数定義
├── outputs.tf        # 出力定義
├── providers.tf      # プロバイダー設定
├── modules/
│   ├── vpc/          # VPCモジュール
│   ├── opensearch/   # OpenSearchモジュール
│   ├── api-gateway/  # API Gatewayモジュール
│   ├── lambda/       # Lambdaモジュール
│   └── cognito/      # Cognitoモジュール
└── environments/
    ├── dev/          # 開発環境
    ├── stg/          # ステージング環境
    └── prod/         # 本番環境
```

## 前提条件

- Terraform >= 1.0
- AWS CLI設定済み
- 適切なIAM権限

## 使用方法

```bash
# 初期化
terraform init

# プラン確認
terraform plan

# 適用
terraform apply
```

## 主要リソース

### VPC
- マルチAZ構成（3AZ）
- パブリック/プライベートサブネット
- NAT Gateway
- VPCエンドポイント（OpenSearch用）

### OpenSearch Service
- 3ノードクラスター
- マルチAZ配置
- 暗号化（保存時・転送時）
- VPC内配置

### API Gateway
- REST API
- Cognito認証統合
- スロットリング設定
- WAF連携

### Lambda
- 検索API
- インデックス更新API
- VPC内配置

### Cognito
- User Pool
- Identity Pool
- OAuth 2.0 / OIDC

## セキュリティ

- 全リソースVPC内配置
- IAMロールによる最小権限
- 暗号化（KMS）
- WAFによる保護
- CloudTrailによる監査

## 監視

- CloudWatch Metrics
- CloudWatch Logs
- CloudWatch Alarms
- OpenSearchダッシュボード

## コスト見積もり（月額概算）

| リソース | 構成 | 概算コスト |
|---------|------|-----------|
| OpenSearch | t3.medium.search x 3 | $200 |
| API Gateway | 1M リクエスト | $10 |
| Lambda | 1M 実行 | $5 |
| VPC | NAT Gateway | $50 |
| **合計** | | **$265/月** |

※実際のコストは使用量により変動
