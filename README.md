# Business - デモプロジェクト管理リポジトリ

## 概要

技術面接・ポートフォリオ用のデモプロジェクトを管理するリポジトリです。

## 構成

```
Business/
├── project-a/             # 案件A準備資料
├── project-b/             # 案件B準備資料
└── demo-projects/         # 技術デモプロジェクト
    ├── k8s-github-actions-demo/     # Day 1: Kubernetes + GitHub Actions CI/CD
    ├── mlops-pipeline-demo/         # Day 2: MLOps パイプライン
    └── sre-monitoring-demo/         # Day 3: SRE 監視基盤
```

---

## デモプロジェクト

面接・技術デモ用に作成した3つの実践的なプロジェクトです。すべてローカル環境（Docker Compose）で完全に動作します。

### Day 1: Kubernetes + GitHub Actions CI/CD デモ

**技術スタック**: Kubernetes, GitHub Actions, Minikube, Docker

**デモ内容**:
- Kubernetesマニフェストによるアプリケーションデプロイ
- GitHub Actionsによる自動CI/CDパイプライン
- ローカルMinikube環境での動作確認

📁 プロジェクト: [demo-projects/k8s-github-actions-demo](./demo-projects/k8s-github-actions-demo)

---

### Day 2: MLOps パイプラインデモ

**技術スタック**: MLflow, scikit-learn, Docker Compose, Jupyter, Python

**デモ内容**:
- MLflowによる実験管理・モデルバージョニング
- 機械学習パイプライン（前処理・訓練・評価）
- Jupyter Notebookによるデータ探索
- Docker Composeによるマイクロサービス構成

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

## ライセンス

このリポジトリは個人のポートフォリオ・技術面接用です。

---

**作成日**: 2026-01-13
**管理者**: (internal)
