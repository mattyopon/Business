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

**構成要素**:
- VPC（マルチAZ構成）
- OpenSearch Service
- API Gateway + Lambda
- Cognito（認証）
- ECS Fargate（アプリケーション）

### opensearch-demo

OpenSearchの基本的な操作・クエリ例。

**内容**:
- インデックス作成
- マッピング定義
- データ投入
- 検索クエリ例
