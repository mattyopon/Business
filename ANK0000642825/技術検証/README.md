# 技術検証

検索システムインフラ構築支援案件に関連する技術検証デモです。

## デモ一覧

| デモ | 説明 |
|------|------|
| [terraform-aws-search](terraform-aws-search/) | Terraformによる検索システムインフラ構築 |
| [opensearch-demo](opensearch-demo/) | OpenSearchクラスター設定・クエリ例 |

## 概要

### terraform-aws-search

AWSで検索システムを構築するためのTerraformコード。

**構成要素 (本リポ同梱の Terraform 実装範囲)**:
- VPC + Public/Private サブネット + NAT Gateway (`modules/vpc/`)
- OpenSearch Service Domain (VPC内 / FGAC / KMS 暗号化 / TLS 1.2 / Slow Log 3種類取込)
- API Gateway REST API (リソース 1本 `/search` GET + Cognito Authorizer)
- Cognito User Pool + App Client (SRP / Refresh Token 認証フロー)
- KMS CMK / CloudWatch Logs / Lambda-SG / OpenSearch-SG

**本リポでは未実装 (案件参画時に実装)**:
- Lambda 統合 (Search/Index 関数)
- API Gateway デプロイ / ステージ / Usage Plan / WAF 連携 / スロットリング
- Cognito Hosted UI Domain / Identity Pool / OAuth スコープ強制
- CloudFront / VPC Endpoint / CloudTrail Trail
- ECS Fargate (本案件は Lambda + OpenSearch 構成のため ECS は不採用)

### opensearch-demo

OpenSearchの基本的な操作・クエリ例。

**内容**:
- インデックス作成
- マッピング定義
- データ投入
- 検索クエリ例
