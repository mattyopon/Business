# AWSインフラ設計書

## 1. 概要

### 1.1 目的
本ドキュメントは、検索システムのAWSインフラ設計を定義する。

### 1.2 対象環境

| 環境 | 用途 | リージョン |
|------|------|-----------|
| Production | 本番環境 | ap-northeast-1 |
| Staging | 検証環境 | ap-northeast-1 |
| Development | 開発環境 | ap-northeast-1 |

---

## 2. ネットワーク設計

### 2.1 VPC構成

| 項目 | 本番環境 | 開発環境 |
|------|---------|---------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 |
| AZ数 | 3 | 2 |

### 2.2 サブネット設計

| サブネット | CIDR | 用途 |
|-----------|------|------|
| Public-1a | 10.0.1.0/24 | ALB、NAT Gateway |
| Public-1c | 10.0.2.0/24 | ALB、NAT Gateway |
| Public-1d | 10.0.3.0/24 | ALB、NAT Gateway |
| Private-1a | 10.0.11.0/24 | アプリケーション |
| Private-1c | 10.0.12.0/24 | アプリケーション |
| Private-1d | 10.0.13.0/24 | アプリケーション |
| Data-1a | 10.0.21.0/24 | OpenSearch、RDS |
| Data-1c | 10.0.22.0/24 | OpenSearch、RDS |

### 2.3 ルーティング

**パブリックサブネット**:
- インターネットゲートウェイ経由で外部通信

**プライベートサブネット**:
- NAT Gateway経由で外部通信
- VPCエンドポイント経由でAWSサービスアクセス

### 2.4 VPCエンドポイント

| サービス | タイプ | 用途 |
|---------|--------|------|
| S3 | Gateway | S3アクセス |
| ECR | Interface | コンテナイメージ取得 |
| CloudWatch Logs | Interface | ログ送信 |
| Secrets Manager | Interface | シークレット取得 |

---

## 3. コンピューティング / 公開エンドポイント設計

本案件のフロントは **API Gateway (REST) + Cognito Authorizer + Lambda (検索 / 投入)** で構成する。商談資料・03_API-Gateway設計書・terraform-aws-search と用語を揃える。
ECS Fargate / EKS の常駐アプリ層は本案件のスコープ外 (必要が出た段階で別設計書を起票する)。

### 3.1 API Gateway (REST)

| 項目 | 本番環境 | 開発環境 |
|------|---------|---------|
| API 名 | search-prod-api | search-dev-api |
| エンドポイントタイプ | REGIONAL (CloudFront / WAF 連携) | REGIONAL |
| 認可 | Cognito Authorizer (User Pool 連携) | 同上 |
| スロットリング (アカウント) | 10000 RPS / Burst 5000 | 1000 RPS / Burst 500 |
| ステージ | `v1` | `v1` |

詳細は `03_API-Gateway設計書.md` を参照。

### 3.2 Lambda

| 関数名 | ランタイム | メモリ | タイムアウト | 用途 |
|--------|----------|--------|------------|------|
| search-api | Python 3.12 | 512MB | 30秒 | `/v1/search` の検索処理 (opensearch-py + AWS4Auth で OpenSearch を叩く) |
| suggest-api | Python 3.12 | 256MB | 10秒 | `/v1/search/suggest` の補完検索 |
| index-updater | Python 3.12 | 1024MB | 300秒 | `/v1/indices/*` の投入・削除 (admin scope 必須) |

すべて VPC 内 (Lambda-SG) に配置し、OpenSearch ドメインに接続する。

### 3.3 Auto Scaling (Lambda Provisioned Concurrency)

| 項目 | 設定値 |
|------|--------|
| search-api | Provisioned Concurrency 5 (本番) / 0 (dev) |
| スケーリング指標 | Lambda Concurrent Executions / Duration p95 |
| 上限 | アカウント上限の 80% で CloudWatch アラート |

---

## 4. ストレージ設計

### 4.1 S3バケット

| バケット名 | 用途 | ライフサイクル |
|-----------|------|--------------|
| search-prod-logs | アクセスログ | 90日でGlacier |
| search-prod-backup | バックアップ | 365日で削除 |
| search-prod-data | 静的データ | なし |

### 4.2 S3バケットポリシー

- パブリックアクセス：すべてのバケットで `BlockPublicAcls` / `IgnorePublicAcls` / `BlockPublicPolicy` / `RestrictPublicBuckets` を有効
- 暗号化：**カスタマー管理 KMS (CMK)** を必須とする (`05_セキュリティガイドライン.md` 「データ保護」と整合)。`aws/s3` マネージドキー / `SSE-S3` は本案件では採用しない
- バージョニング：有効
- Object Lock：監査ログバケット (`search-prod-audit-logs`) で `Compliance` モード、保持期間 7年

---

## 5. セキュリティ設計

### 5.1 セキュリティグループ

API Gateway / Cognito / CloudFront / KMS / CloudWatch Logs は AWS マネージドサービスで SG を持たない。SG は VPC 内のリソース (Lambda / OpenSearch) のみに付与する。

| SG名 | インバウンド | アウトバウンド |
|------|------------|--------------|
| lambda-sg | なし (Lambda は受信を持たない) | All (OpenSearch / 外部 API への TLS) |
| opensearch-sg | 443/tcp from lambda-sg | All |

### 5.2 IAM ロール

| ロール名 | Trust | 主なポリシー |
|---------|------|------------|
| search-api-lambda-role | `lambda.amazonaws.com` | `es:ESHttp*` (search domain ARN), `kms:Decrypt`, `logs:*` |
| index-updater-lambda-role | `lambda.amazonaws.com` | `es:ESHttp*` (admin), `s3:GetObject` (source bucket), `kms:Decrypt`, `logs:*` |
| opensearch-master-user-role | `sts:AssumeRole` を許可 (運用者の IAM Identity Center / search-api-lambda-role / index-updater-lambda-role が `assume` できる Trust ポリシー) | OpenSearch FGAC の master_user として `all_access` ロールに紐付け |
| ci-cd-deploy-role | `token.actions.githubusercontent.com` (GitHub OIDC + WIF) | `aws_eks_cluster:*`, `lambda:UpdateFunctionCode`, `s3:Put`, 等を絞り込み |

> **重要**: `opensearch-master-user-role` の Trust は `es.amazonaws.com` だけにしないこと。それだと運用者・Lambda どちらも `AssumeRole` できず、IAM 認証で OpenSearch を管理できない。`terraform-aws-search/main.tf` の `aws_iam_role.opensearch_master.assume_role_policy` も同方針で構成すること (Trust に運用 SSO ロールおよび Lambda 実行ロールの ARN を `Principal.AWS` で列挙)。

---

## 6. 監視設計

### 6.1 CloudWatch Metrics

| メトリクス | 閾値 | アラート |
|-----------|------|---------|
| CPU使用率 | > 80% | Warning |
| Memory使用率 | > 80% | Warning |
| 5xxエラー率 | > 1% | Critical |
| レイテンシP95 | > 500ms | Warning |

### 6.2 CloudWatch Logs

| ログ名 | 保持期間 |
|--------|---------|
| /ecs/search-app | 30日 |
| /aws/lambda/search-api | 30日 |
| /aws/opensearch/search-prod | 30日 |

---

## 7. バックアップ設計

### 7.1 バックアップスケジュール

| 対象 | 頻度 | 保持期間 |
|------|------|---------|
| OpenSearch | 1時間ごと（自動） | 14日 |
| S3 | バージョニング | 無期限 |

### 7.2 リカバリ手順

1. OpenSearch: スナップショットからリストア
2. S3: バージョニングから復元

---

## 8. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
