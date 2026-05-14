# Terraform AWS Search Infrastructure

AWSで検索システムインフラを構築するTerraformコードです。

## アーキテクチャ (本リポ同梱の実装範囲)

```
              ┌────────────────────┐
              │   API Gateway      │
              │ (REST / GET /search)│
              │  + Cognito Authorizer
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────┐
              │    Cognito         │
              │ User Pool + App    │
              │ Client (SRP 認証)  │
              └────────────────────┘

      (VPC 内)
              ┌────────────────────┐
              │   OpenSearch       │
              │ Domain (FGAC + KMS)│
              └────────────────────┘
              ※ Lambda 統合は本リポ未実装。商談用Q&A・03_API-Gateway設計書では
                Lambda Proxy + Cognito スコープ強制を実装方針として記述している
                が、それらは本案件参画時に並走で実装する想定。

将来拡張: CloudFront + WAF + Identity Pool + VPC Endpoint + Lambda は別途追加 (本リポには未同梱)。
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

### API Gateway (本リポ実装範囲)
- REST API 1 リソース (`/search` GET) + Cognito Authorizer 1 つ
- ステージ / デプロイ / Usage Plan / WAF 連携 / スロットリング: **未実装** (本案件参画時に並走で実装)

### Lambda (本リポ実装範囲)
- **未実装** (本リポは API Gateway + Cognito + OpenSearch の骨格検証のみ)

### Cognito (本リポ実装範囲)
- User Pool + App Client + Authorizer の最小構成
- **Identity Pool / Hosted UI Domain / Cognito Groups / OAuth スコープ強制 / Lambda Trigger: 未実装**

## セキュリティ

- OpenSearch はプライベートサブネット内配置 (VPC option 有効化、Lambda 統合は未実装のため Lambda-SG は受信なしで定義のみ)
- API Gateway / Cognito / KMS / CloudWatch Logs は AWS マネージドサービス (VPC外)。API Gateway は Cognito User Pool 認証必須に設定
- IAMロールによる最小権限 (OpenSearch master user は同一アカウント内 IAM プリンシパルが AssumeRole する Trust 設計)
- 暗号化: 保存時 (KMS CMK + key rotation 有効) / 転送時 (TLS 1.2 以上を enforce)
- WAF / CloudFront / VPC Endpoint / CloudTrail / VPC Flow Logs: 本デモのスコープ外 (要件確定時に追加)

## 監視

- 本リポは Slow Log 3種類 (Search/Indexing/Application) を CloudWatch Logs へ取り込む構成まで実装
- CloudWatch Metrics アラーム / OpenSearch ダッシュボード設定 / Composite Alarm: **未実装** (運用ガイド `02_OpenSearch運用ガイド.md` および `04_監視設計書.md` で設計のみ記述)

## コスト見積もり（月額概算 / ap-northeast-1 / dev 想定 / 本リポ実装範囲のみ）

| リソース | 構成 | 概算コスト (USD) |
|---------|------|-----------|
| OpenSearch | t3.medium.search x 2 (24h) | $100 |
| OpenSearch EBS | gp3 100GB x 2 | $20 |
| NAT Gateway | 1台 (dev は single_nat_gateway=true) | $35 (時間料金) + データ処理量別途 |
| データ転送 | NAT/Internet egress 100GB 想定 | $9 |
| API Gateway | 1M リクエスト想定 (本リポは REST API リソース定義のみ) | $4 |
| Cognito | MAU 1万人以下は無料枠 | $0 |
| KMS | CMK 1個 + 30万リクエスト | $4 |
| CloudWatch Logs | 取込 5GB / 保管 30日 | $5 |
| **合計 (概算)** | | **$177/月 前後** |

> Lambda は本リポ未実装のため含めていません。実装時は 1M 実行で +$1 程度を見込んでください。

> NAT Gateway はデータ処理量課金 ($0.062/GB) が大きく、トラフィック量で大きく変動します。
> stg/prod 構成 (3AZ / dedicated master / multi-NAT) では本テーブルの 2-3倍を想定してください。
> 実際のコストは AWS Pricing Calculator で必ず再計算してください。
