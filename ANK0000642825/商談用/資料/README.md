# 商談用資料

PDF・画像ファイルを格納するディレクトリです。

## ファイル一覧

| ファイル名 | 内容 |
|-----------|------|
| 01_システム構成図.png | AWS検索システム全体構成図 |
| 02_OpenSearchアーキテクチャ図.png | OpenSearch Service中心のアーキテクチャ図 |
| 03_セキュリティ構成図.png | 多層防御セキュリティ構成図 |
| 04_CI-CDパイプライン図.png | CI/CDパイプラインフロー図 |
| 05_監視ダッシュボード構成.png | CloudWatch/Grafana監視ダッシュボード構成 |

## 資料概要

### システム構成図
- VPC、サブネット構成
- CloudFront → API Gateway → ECS Fargate/Lambda → OpenSearch
- ElastiCache（Redis）キャッシュ層
- S3データストレージ

### OpenSearchアーキテクチャ
- 3ノードクラスター構成
- データ投入・検索フロー
- キャッシュ戦略（Cache-Aside）

### セキュリティ構成
- 5層防御（Perimeter → Network → Identity → Data → Detection）
- WAF、Cognito、KMS、GuardDuty

### CI/CDパイプライン
- GitHub Actions → ECR → ECS Fargate
- Blue-Green/Canaryデプロイ

### 監視ダッシュボード
- OpenSearch、ECS、API Gateway、ElastiCacheメトリクス
- アラート設定

---

**注意**: GenSpark_プロンプト.mdは内部作業用のためgitには含まれません。
