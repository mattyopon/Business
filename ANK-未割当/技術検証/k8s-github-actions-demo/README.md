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

# 2. アプリのコンテナイメージをビルド & Minikube に取り込む
#    (Deployment の imagePullPolicy: Never でローカルイメージ前提のため事前ロードが必須)
eval $(minikube docker-env)
docker build -t demo-app:latest ./app

# 3. デプロイ
kubectl apply -f kubernetes/

# 4. サービス確認
kubectl get all

# 5. アプリにアクセス
minikube service demo-app-service
```

> **注**: `kubernetes/deployment.yaml` は `image: demo-app:latest` + `imagePullPolicy: Never` を前提にしているため、
> 上記の step 2 (Minikube 内ビルド) を **必ず先に実行** する必要があります。これを省略すると `ImagePullBackOff` で起動しません。
> リモートレジストリ (GHCR / Docker Hub / ECR) からの pull に切り替える場合は `image:` を完全修飾名にし、`imagePullPolicy: IfNotPresent` に変更してください。

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
