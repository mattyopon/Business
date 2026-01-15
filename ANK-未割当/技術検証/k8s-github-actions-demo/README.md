# Kubernetes + GitHub Actions Demo

インフラ開発案件向けのKubernetes + CI/CDデモプロジェクトです。

## 概要

このプロジェクトは以下を実装しています:
- Minikubeを使ったローカルKubernetes環境
- シンプルなNode.jsアプリケーション
- GitHub ActionsによるCI/CDパイプライン

## 前提条件

```bash
# Docker Desktop
# kubectl
# Minikube
```

## クイックスタート

```bash
# 1. Minikube起動
minikube start

# 2. デプロイ
kubectl apply -f kubernetes/

# 3. サービス確認
kubectl get all

# 4. アプリにアクセス
minikube service demo-app-service
```

## ディレクトリ構成

```
k8s-github-actions-demo/
├── app/                    # アプリケーションコード
│   ├── server.js          # Node.jsサーバー
│   ├── package.json
│   └── Dockerfile
├── kubernetes/             # K8s マニフェスト
│   ├── deployment.yaml    # Deployment
│   ├── service.yaml       # Service
│   └── configmap.yaml     # ConfigMap
├── .github/
│   └── workflows/
│       └── ci-cd.yml      # CI/CDパイプライン
└── README.md
```

## 学習ポイント

- Kubernetes の基本リソース (Pod, Deployment, Service)
- kubectl コマンド
- GitHub Actions ワークフロー
- Docker イメージビルドとデプロイ
