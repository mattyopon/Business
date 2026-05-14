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
├── main.tf           # OpenSearch / API Gateway / Cognito / KMS / SG / IAM / CloudWatch Logs
├── variables.tf      # 入力変数 (環境は environment 変数で dev/stg/prod を切替)
├── outputs.tf        # VPC ID / OpenSearch endpoint / API Gateway / Cognito 等
├── providers.tf      # AWS provider と terraform required_version
└── modules/
    └── vpc/          # VPC / Subnet / IGW / NAT / Route Table
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

> 環境 (dev/stg/prod) は `environment` 変数 + tfvars で切り替える single-config 構成です。
> 必要に応じて `environments/<env>.tfvars` を追加し `terraform apply -var-file=...` で運用してください。
> OpenSearch / API Gateway / Cognito 等の追加モジュール化は今後の拡張対象です。

## 前提条件

- Terraform >= 1.0
- AWS CLI設定済み
- 適切なIAM権限

## 使用方法

```bash
# 初期化
terraform init

# プラン確認 (dev環境)
terraform plan -var="environment=dev"

# 適用
terraform apply -var="environment=dev"
```

`environment` を `stg` / `prod` に切り替えると、OpenSearchの zone_awareness や dedicated master 等が変化します (詳細は `main.tf` 内の dynamic block 参照)。

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

- OpenSearch / Lambda はプライベートサブネット内配置 (VPC option 有効化)
- API Gateway / Cognito / KMS / CloudWatch Logs は AWS マネージドサービス (VPC外)。API Gateway は Cognito User Pool 認証必須に設定
- IAMロールによる最小権限 (OpenSearch master user は dedicated role を assume)
- 暗号化: 保存時 (KMS CMK + key rotation 有効) / 転送時 (TLS 1.2 以上を enforce)
- WAF は ALB / CloudFront 経由で API Gateway を保護する想定 (本リポではコメントアウト、要件次第で別途追加)
- CloudTrail / VPC Flow Logs は別レイヤーで集約 (本デモのスコープ外)

## 監視

- CloudWatch Metrics
- CloudWatch Logs
- CloudWatch Alarms
- OpenSearchダッシュボード

## コスト見積もり（月額概算 / ap-northeast-1 / dev想定）

| リソース | 構成 | 概算コスト (USD) |
|---------|------|-----------|
| OpenSearch | t3.medium.search x 2 (24h) | $100 |
| OpenSearch EBS | gp3 100GB x 2 | $20 |
| NAT Gateway | 1台 (dev は single_nat_gateway=true) | $35 (時間料金) + データ処理量別途 |
| データ転送 | NAT/Internet egress 100GB 想定 | $9 |
| API Gateway | 1M リクエスト | $4 |
| Lambda | 1M 実行 (128MB / 200ms) | $1 |
| Cognito | MAU 1万人以下は無料枠 | $0 |
| KMS | CMK 1個 + 30万リクエスト | $4 |
| CloudWatch Logs | 取込 5GB / 保管 30日 | $5 |
| **合計 (概算)** | | **$178/月 前後** |

> NAT Gateway はデータ処理量課金 ($0.062/GB) が大きく、トラフィック量で大きく変動します。
> stg/prod 構成 (3AZ / dedicated master / multi-NAT) では本テーブルの 2-3倍を想定してください。
> 実際のコストは AWS Pricing Calculator で必ず再計算してください。
