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

## 3. コンピューティング設計

### 3.1 ECS Fargate

| 項目 | 本番環境 | 開発環境 |
|------|---------|---------|
| クラスター名 | search-prod-cluster | search-dev-cluster |
| 起動タイプ | Fargate | Fargate |
| タスク数 | 3〜10（Auto Scaling） | 1〜2 |
| CPU | 1024 | 512 |
| Memory | 2048 | 1024 |

### 3.2 Auto Scaling

**スケーリングポリシー**:
- **スケールアウト**: CPU使用率 > 70% が5分継続
- **スケールイン**: CPU使用率 < 30% が10分継続
- **最小タスク数**: 3
- **最大タスク数**: 10

### 3.3 Lambda

| 関数名 | ランタイム | メモリ | タイムアウト | 用途 |
|--------|----------|--------|------------|------|
| search-api | Python 3.11 | 512MB | 30秒 | 検索API |
| index-updater | Python 3.11 | 1024MB | 300秒 | インデックス更新 |

---

## 4. ストレージ設計

### 4.1 S3バケット

| バケット名 | 用途 | ライフサイクル |
|-----------|------|--------------|
| search-prod-logs | アクセスログ | 90日でGlacier |
| search-prod-backup | バックアップ | 365日で削除 |
| search-prod-data | 静的データ | なし |

### 4.2 S3バケットポリシー

- パブリックアクセス：ブロック
- 暗号化：SSE-S3
- バージョニング：有効

---

## 5. セキュリティ設計

### 5.1 セキュリティグループ

| SG名 | インバウンド | アウトバウンド |
|------|------------|--------------|
| alb-sg | 443 from 0.0.0.0/0 | All |
| app-sg | 8080 from alb-sg | All |
| opensearch-sg | 443 from app-sg, lambda-sg | All |
| lambda-sg | なし | All |

### 5.2 IAMロール

| ロール名 | 用途 | 主なポリシー |
|---------|------|------------|
| ecs-task-role | ECSタスク実行 | S3、SecretsManager |
| ecs-exec-role | ECSタスク定義 | ECR、CloudWatch |
| lambda-exec-role | Lambda実行 | OpenSearch、S3 |

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
