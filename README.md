# Business - 案件管理リポジトリ

## 概要

案件ごとの商談資料・技術ドキュメント・技術検証デモを管理するリポジトリです。

## ディレクトリ構成

```
Business/
├── ANK0000639199/           # 医療IT・MLOps/SRE案件
│   ├── 商談用/              # 商談・面談資料
│   ├── 参画用/              # 参画後の設計・運用ドキュメント
│   │   └── 運用ドキュメント/ # 実務用運用マニュアル（8種）
│   └── 技術検証/            # 技術デモプロジェクト
│
└── ANK-未割当/              # 未割当案件用テンプレート
    └── 技術検証/            # 汎用技術デモ
```

---

## 案件一覧

| 案件番号 | 業種 | 概要 | ステータス |
|---------|------|------|----------|
| [ANK0000639199](./ANK0000639199/) | 医療IT | 医療AIプラットフォームのインフラ構築 | 商談中 |
| [ANK-未割当](./ANK-未割当/) | - | 新規案件用テンプレート | - |

---

## ANK0000639199 - 医療IT・MLOps/SRE案件

### 作業内容
- AWSを中心としたクラウドインフラの設計、構築、運用
- AIモデル運用のためのMLOpsパイプライン構築
- IaC（Terraform/CloudFormation）による環境構築自動化
- コンテナ（Docker/ECS/EKS）ベースの運用管理
- 監視・ログ設計・アラート基盤などのSRE活動
- セキュリティ・医療データガバナンス対応
- HPC環境の運用（AI向け高負荷処理）

### 資料構成

#### 商談用
| 資料 | 説明 |
|------|------|
| [商談準備資料](./ANK0000639199/商談用/商談準備資料.md) | 経歴紹介・質疑応答準備 |
| [技術用語解説](./ANK0000639199/商談用/技術用語解説.md) | 基礎的な技術用語の解説集 |
| [想定Q&A](./ANK0000639199/商談用/想定Q&A.md) | 技術的な深掘り質問への回答 |
| [ヒアリングシート](./ANK0000639199/商談用/ヒアリングシート.md) | 商談時の確認項目・医療AIユースケース |

#### 運用ドキュメント（8種）
| 資料 | 説明 |
|------|------|
| [AWSインフラ設計書](./ANK0000639199/参画用/運用ドキュメント/01_AWSインフラ設計書.md) | VPC/EKS/Aurora等のインフラ設計 |
| [MLOpsパイプライン設計書](./ANK0000639199/参画用/運用ドキュメント/02_MLOpsパイプライン設計書.md) | データパイプライン・モデル管理 |
| [IaC運用ガイドライン](./ANK0000639199/参画用/運用ドキュメント/03_IaC運用ガイドライン.md) | Terraform/CloudFormation運用規約 |
| [コンテナ運用マニュアル](./ANK0000639199/参画用/運用ドキュメント/04_コンテナ運用マニュアル.md) | Docker/EKS/ECS運用手順 |
| [SRE監視設計書](./ANK0000639199/参画用/運用ドキュメント/05_SRE監視設計書.md) | Prometheus/Grafana監視設計 |
| [セキュリティガバナンス](./ANK0000639199/参画用/運用ドキュメント/06_セキュリティガバナンス.md) | 医療データコンプライアンス対応 |
| [HPC環境運用ガイド](./ANK0000639199/参画用/運用ドキュメント/07_HPC環境運用ガイド.md) | GPU/AWS Batch環境運用 |
| [技術選定プロセス](./ANK0000639199/参画用/運用ドキュメント/08_技術選定プロセス.md) | 技術評価・ADR作成プロセス |

#### 技術検証
| プロジェクト | 説明 |
|-------------|------|
| [terraform-aws-infra](./ANK0000639199/技術検証/terraform-aws-infra/) | IaCによるAWSインフラ構築デモ（EKS, Aurora, VPC） |
| [mlops-pipeline-demo](./ANK0000639199/技術検証/mlops-pipeline-demo/) | MLOpsパイプラインのデモ実装 |
| [sre-monitoring-demo](./ANK0000639199/技術検証/sre-monitoring-demo/) | Prometheus/Grafanaによる監視デモ |

---

## 技術スキルマップ

| 技術領域 | 使用技術 | 関連デモ |
|---------|---------|---------|
| **クラウド** | AWS (EKS, Aurora, S3, CloudFront, WAF) | terraform-aws-infra |
| **IaC** | Terraform, CloudFormation | terraform-aws-infra |
| **コンテナ** | Docker, Kubernetes, ECS, EKS | mlops-pipeline-demo |
| **MLOps** | MLflow, SageMaker, Kubeflow | mlops-pipeline-demo |
| **監視/SRE** | Prometheus, Grafana, CloudWatch | sre-monitoring-demo |
| **セキュリティ** | IAM, KMS, WAF, 医療データガバナンス | 運用ドキュメント |
| **HPC** | AWS Batch, GPU (p4d/g5), FSx | 運用ドキュメント |

---

## クイックスタート

```bash
# MLOps デモ起動
cd ANK0000639199/技術検証/mlops-pipeline-demo
docker-compose up -d
# MLflow UI: http://localhost:5000

# SRE監視デモ起動
cd ANK0000639199/技術検証/sre-monitoring-demo
docker-compose up -d
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

---

## 新規案件の追加方法

1. `ANK-未割当` をコピーして新しい案件番号のディレクトリを作成
2. 案件情報をREADME.mdに記載
3. 必要に応じて商談用資料を準備
4. 技術検証が必要な場合はデモプロジェクトを追加

---

**管理者**: mattyopon
**最終更新**: 2026-01-15
