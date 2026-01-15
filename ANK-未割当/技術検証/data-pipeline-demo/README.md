# データ処理パイプライン デモ

GitHub Actions + Kubernetesを使ったデータ処理パイプラインのデモです。

## 概要

本デモは、Kubernetesジョブとして実行されるデータ処理パイプラインを構築します。

### 構成

- **GitHub Actions**: パイプラインのトリガー、オーケストレーション
- **Kubernetes Jobs**: データ処理の実行環境
- **Argo Workflows**: 複雑なDAGワークフロー（オプション）

## ディレクトリ構成

```
data-pipeline-demo/
├── README.md
├── .github/
│   └── workflows/
│       ├── daily-etl.yml        # 日次ETLパイプライン
│       └── on-demand-process.yml # オンデマンド処理
├── kubernetes/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml              # テンプレート
│   └── jobs/
│       ├── extract-job.yaml
│       ├── transform-job.yaml
│       └── load-job.yaml
├── src/
│   ├── extract/
│   │   └── main.py
│   ├── transform/
│   │   └── main.py
│   └── load/
│       └── main.py
└── docker/
    └── Dockerfile
```

## パイプラインフロー

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Extract   │────>│  Transform  │────>│    Load     │
│  (データ取得) │     │  (データ変換) │     │ (データ投入) │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      v                   v                   v
  S3/API              Kubernetes          Database
  Source               Job                 Target
```

## GitHub Actions ワークフロー

### 日次ETL（daily-etl.yml）

```yaml
name: Daily ETL Pipeline

on:
  schedule:
    - cron: '0 2 * * *'  # 毎日AM2時（UTC）
  workflow_dispatch:

jobs:
  etl:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}

      - name: Run Extract Job
        run: kubectl apply -f kubernetes/jobs/extract-job.yaml

      - name: Wait for Extract
        run: kubectl wait --for=condition=complete job/extract-job --timeout=600s

      - name: Run Transform Job
        run: kubectl apply -f kubernetes/jobs/transform-job.yaml

      - name: Wait for Transform
        run: kubectl wait --for=condition=complete job/transform-job --timeout=600s

      - name: Run Load Job
        run: kubectl apply -f kubernetes/jobs/load-job.yaml

      - name: Wait for Load
        run: kubectl wait --for=condition=complete job/load-job --timeout=600s

      - name: Cleanup Jobs
        run: |
          kubectl delete job extract-job transform-job load-job
```

## Kubernetes Job 定義例

### Extract Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: extract-job
  namespace: data-pipeline
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      containers:
      - name: extract
        image: data-pipeline:latest
        command: ["python", "src/extract/main.py"]
        env:
        - name: SOURCE_BUCKET
          valueFrom:
            configMapKeyRef:
              name: pipeline-config
              key: source_bucket
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: access_key_id
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      restartPolicy: Never
  backoffLimit: 3
```

## 学習ポイント

- Kubernetes Jobsによるバッチ処理
- GitHub ActionsでのCI/CDとワークフロー連携
- 環境変数とSecretsの管理
- リソース制限とバックオフ設定

## 参考資料

- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Argo Workflows](https://argoproj.github.io/argo-workflows/)
