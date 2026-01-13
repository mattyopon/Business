# Business - 案件・デモプロジェクト管理リポジトリ

## 概要

技術面接・ポートフォリオ用の案件情報とデモプロジェクトを管理するリポジトリです。

## 構成

```
Business/
├── woven-toyota/          # ウーブン・バイ・トヨタ株式会社 案件情報
├── epimetrix/             # EpiMetrix株式会社 案件情報
└── demo-projects/         # 技術デモプロジェクト
    ├── k8s-github-actions-demo/     # Day 1: Kubernetes + GitHub Actions CI/CD
    ├── mlops-pipeline-demo/         # Day 2: MLOps パイプライン
    └── sre-monitoring-demo/         # Day 3: SRE 監視基盤
```

---

## 案件情報

### 1. ウーブン・バイ・トヨタ株式会社

- **プロジェクト**: スマートシティ向けAIアプリケーション開発
- **URL**: https://woven.toyota/jp/
- **契約形態**: 派遣契約
- **給与**: 〜6,300円/時（税込）
- **期間**: 2026-02-01 〜 長期予定
- **場所**: 三越前(東京メトロ銀座線)

**必要スキル**:
- バックエンドソフトウェア開発経験
- IaC (Infrastructure as Code) の経験
- ビジネスレベルの日本語能力

**作業内容**:
- Kubernetesを用いたインフラの開発、保守
- データ処理パイプラインの開発、保守
- GitHub Actionsを用いたCI/CDパイプラインの開発、保守

📁 詳細: [woven-toyota/README.md](./woven-toyota/README.md)

---

### 2. EpiMetrix株式会社

- **プロジェクト**: 医療業界向けクラウドインフラ構築
- **URL**: https://epimetrix.co.jp/
- **契約形態**: 業務委託
- **単価**: 60〜90万円/月（税込）
- **期間**: 即日 〜 延長の可能性あり
- **場所**: 御成門(都営三田線)
- **募集人員**: 3名

**必要スキル**:
- AWSでのクラウドインフラ構築や運用経験(5年以上)
- MLOps構築や運用経験
- IaCの知見や運用経験
- コンテナ技術の知見や運用経験
- SREに関する知見

**作業内容**:
- AWSを中心としたクラウドインフラの設計、構築、運用、保守
- AIモデル運用のためのMLOpsパイプライン構築、改善
- IaC(Terraform、CloudFormationなど)による環境構築の自動化
- コンテナ(Docker、ECS、EKS)ベースの運用管理
- 監視、ログ設計、アラート基盤などのSRE活動

📁 詳細: [epimetrix/README.md](./epimetrix/README.md)

---

## デモプロジェクト

面接・技術デモ用に作成した3つの実践的なプロジェクトです。すべてローカル環境（Docker Compose）で完全に動作します。

### Day 1: Kubernetes + GitHub Actions CI/CD デモ

**技術スタック**: Kubernetes, GitHub Actions, Minikube, Docker

**デモ内容**:
- Kubernetesマニフェストによるアプリケーションデプロイ
- GitHub Actionsによる自動CI/CDパイプライン
- ローカルMinikube環境での動作確認

**関連案件**: ウーブン・バイ・トヨタ（Kubernetes、GitHub Actions CI/CD）

📁 プロジェクト: [demo-projects/k8s-github-actions-demo](./demo-projects/k8s-github-actions-demo)

---

### Day 2: MLOps パイプラインデモ

**技術スタック**: MLflow, scikit-learn, Docker Compose, Jupyter, Python

**デモ内容**:
- MLflowによる実験管理・モデルバージョニング
- 機械学習パイプライン（前処理・訓練・評価）
- Jupyter Notebookによるデータ探索
- Docker Composeによるマイクロサービス構成

**関連案件**: EpiMetrix（MLOps、AWS、Docker）

📁 プロジェクト: [demo-projects/mlops-pipeline-demo](./demo-projects/mlops-pipeline-demo)

**主要機能**:
- 実験トラッキング（パラメータ、メトリクス、モデル）
- モデルレジストリ
- 再現可能なパイプライン
- ローカル完結の開発環境

---

### Day 3: SRE 監視基盤デモ

**技術スタック**: Prometheus, Grafana, Node Exporter, Flask, Docker Compose

**デモ内容**:
- Prometheusによるメトリクス収集
- Grafanaダッシュボードでの可視化
- システムメトリクス監視（CPU、メモリ、ディスク）
- アプリケーションメトリクス（リクエスト率、エラー率、レイテンシ）
- アラートルール設定

**関連案件**: EpiMetrix（SRE、監視基盤、AWS）

📁 プロジェクト: [demo-projects/sre-monitoring-demo](./demo-projects/sre-monitoring-demo)

**主要機能**:
- 4つのGolden Signals監視
- RED Method（Rate, Errors, Duration）
- カスタムメトリクス実装
- 自動プロビジョニング設定

---

## クイックスタート

各プロジェクトはDocker Composeで簡単に起動できます：

```bash
# Day 1: Kubernetes デモ
cd demo-projects/k8s-github-actions-demo
# README.mdの手順に従ってMinikubeセットアップ

# Day 2: MLOps デモ
cd demo-projects/mlops-pipeline-demo
docker-compose up -d
# MLflow UI: http://localhost:5000
# Jupyter: http://localhost:8888

# Day 3: SRE監視デモ
cd demo-projects/sre-monitoring-demo
docker-compose up -d
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

---

## 技術スキルマップ

| 技術領域 | 使用技術 | デモプロジェクト |
|---------|---------|----------------|
| **コンテナ** | Docker, Kubernetes | Day 1, Day 2, Day 3 |
| **CI/CD** | GitHub Actions | Day 1 |
| **MLOps** | MLflow, scikit-learn | Day 2 |
| **監視** | Prometheus, Grafana | Day 3 |
| **IaC** | Docker Compose, K8s Manifests | Day 1, Day 2, Day 3 |
| **言語** | Python, Bash | Day 2, Day 3 |
| **SRE** | メトリクス収集、アラート | Day 3 |

---

## 面接でのアピールポイント

### ウーブン・バイ・トヨタ向け

✅ **Kubernetes経験** - Day 1で実践的なデプロイメントを実装
✅ **GitHub Actions CI/CD** - Day 1で自動化パイプラインを構築
✅ **データパイプライン** - Day 2でMLパイプラインを実装
✅ **IaC経験** - すべてのプロジェクトでInfrastructure as Code

### EpiMetrix向け

✅ **AWS経験** - ローカルで再現可能な構成（AWS移行可能）
✅ **MLOps構築** - Day 2で完全なMLOpsパイプラインを実装
✅ **コンテナ技術** - Docker/Docker Composeの実践的活用
✅ **SRE知見** - Day 3で監視基盤とアラート設定を実装
✅ **IaC** - Terraform代替としてDocker Composeで環境自動化

---

## ライセンス

このリポジトリは個人のポートフォリオ・技術面接用です。

---

**作成日**: 2026-01-13
**管理者**: mattyopon
