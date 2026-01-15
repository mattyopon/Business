# MLOpsパイプライン設計書

## 1. 概要

### 1.1 目的
本ドキュメントは、AIモデルの開発からデプロイ、運用までの一連のMLOpsパイプラインを定義する。

### 1.2 MLOps成熟度レベル
**目標レベル**: Level 2（ML Pipeline Automation）

| レベル | 説明 | 状態 |
|--------|------|------|
| Level 0 | 手動プロセス | - |
| Level 1 | ML Pipeline Automation | - |
| Level 2 | CI/CD Pipeline Automation | 目標 |
| Level 3 | Full MLOps | 将来目標 |

---

## 2. アーキテクチャ概要

### 2.1 MLOpsパイプライン全体図

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MLOps Pipeline                                │
│                                                                       │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │  Data    │───>│  Feature │───>│  Model   │───>│  Model   │       │
│  │ Ingestion│    │Engineering│   │ Training │    │Validation│       │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘       │
│       │               │               │               │              │
│       v               v               v               v              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │   S3     │    │ Feature  │    │  MLflow  │    │  Model   │       │
│  │ Raw Data │    │  Store   │    │ Tracking │    │ Registry │       │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘       │
│                                                       │              │
│                                                       v              │
│                                        ┌──────────────────────┐      │
│                                        │   Model Deployment   │      │
│                                        │   (EKS + Seldon)     │      │
│                                        └──────────────────────┘      │
│                                                       │              │
│                                                       v              │
│                                        ┌──────────────────────┐      │
│                                        │   Model Monitoring   │      │
│                                        │   (Prometheus + ML)  │      │
│                                        └──────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 使用技術スタック

| レイヤー | ツール | 用途 |
|---------|--------|------|
| オーケストレーション | Apache Airflow / Step Functions | パイプライン管理 |
| 実験管理 | MLflow | 実験トラッキング、モデル管理 |
| Feature Store | Feast / SageMaker Feature Store | 特徴量管理 |
| モデルサービング | Seldon Core / KServe | 推論API |
| モデル監視 | Prometheus + Grafana | メトリクス監視 |
| CI/CD | GitHub Actions | 自動化 |

---

## 3. データパイプライン

### 3.1 データ取り込み

```yaml
# データソース定義
data_sources:
  - name: patient_records
    type: database
    connection: aurora_mysql
    frequency: daily

  - name: medical_images
    type: s3
    bucket: medical-ai-raw-data
    frequency: realtime

  - name: external_api
    type: rest_api
    endpoint: https://api.example.com/data
    frequency: hourly
```

### 3.2 データ品質チェック

| チェック項目 | ルール | アクション |
|-------------|--------|----------|
| Null値チェック | 重要カラムのNull率 < 5% | アラート |
| スキーマ検証 | 定義済みスキーマと一致 | 処理停止 |
| 値範囲チェック | 定義済み範囲内 | アラート |
| 重複チェック | 重複率 < 1% | ログ記録 |
| 鮮度チェック | データ遅延 < 1時間 | アラート |

### 3.3 データバージョニング

```
s3://medical-ai-data/
├── raw/
│   └── v1.0.0/
│       ├── 2026-01-15/
│       └── 2026-01-16/
├── processed/
│   └── v1.0.0/
│       ├── features/
│       └── labels/
└── metadata/
    └── catalog.json
```

---

## 4. Feature Store

### 4.1 Feature Store 設計

```python
# Feature定義例
from feast import Entity, Feature, FeatureView, FileSource

patient = Entity(
    name="patient_id",
    value_type=ValueType.STRING,
    description="Patient identifier"
)

patient_features = FeatureView(
    name="patient_features",
    entities=["patient_id"],
    ttl=timedelta(days=1),
    features=[
        Feature(name="age", dtype=ValueType.INT64),
        Feature(name="gender", dtype=ValueType.STRING),
        Feature(name="diagnosis_count", dtype=ValueType.INT64),
        Feature(name="last_visit_days", dtype=ValueType.INT64),
    ],
    online=True,
    batch_source=patient_source,
)
```

### 4.2 Feature Registry

| Feature名 | 型 | 説明 | 更新頻度 |
|-----------|-----|------|----------|
| patient_age | INT | 患者年齢 | 日次 |
| diagnosis_embedding | FLOAT[] | 診断埋め込み | 週次 |
| visit_frequency | FLOAT | 来院頻度 | 日次 |
| risk_score | FLOAT | リスクスコア | リアルタイム |

---

## 5. モデル学習パイプライン

### 5.1 学習パイプライン定義

```python
# Airflow DAG定義
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'mlops-team',
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'model_training_pipeline',
    default_args=default_args,
    schedule_interval='0 2 * * 0',  # 毎週日曜 2:00
    catchup=False,
) as dag:

    data_validation = PythonOperator(
        task_id='validate_data',
        python_callable=validate_training_data,
    )

    feature_engineering = PythonOperator(
        task_id='engineer_features',
        python_callable=create_features,
    )

    model_training = PythonOperator(
        task_id='train_model',
        python_callable=train_model,
    )

    model_evaluation = PythonOperator(
        task_id='evaluate_model',
        python_callable=evaluate_model,
    )

    model_registration = PythonOperator(
        task_id='register_model',
        python_callable=register_to_mlflow,
    )

    data_validation >> feature_engineering >> model_training >> model_evaluation >> model_registration
```

### 5.2 ハイパーパラメータ管理

```yaml
# config/hyperparameters.yaml
model:
  name: medical_diagnosis_model
  version: 1.0.0

hyperparameters:
  learning_rate: 0.001
  batch_size: 32
  epochs: 100
  hidden_layers: [256, 128, 64]
  dropout_rate: 0.3

training:
  early_stopping_patience: 10
  validation_split: 0.2
  random_seed: 42
```

### 5.3 実験トラッキング（MLflow）

```python
import mlflow
import mlflow.sklearn

with mlflow.start_run(run_name="experiment_001"):
    # パラメータ記録
    mlflow.log_params({
        "learning_rate": 0.001,
        "batch_size": 32,
        "epochs": 100,
    })

    # モデル学習
    model = train_model(X_train, y_train)

    # メトリクス記録
    mlflow.log_metrics({
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1_score": f1,
        "auc_roc": auc,
    })

    # モデル保存
    mlflow.sklearn.log_model(model, "model")

    # アーティファクト保存
    mlflow.log_artifact("confusion_matrix.png")
```

---

## 6. モデルデプロイメント

### 6.1 デプロイメント戦略

| 戦略 | 説明 | ユースケース |
|------|------|-------------|
| Blue-Green | 新旧環境を切り替え | 大規模更新 |
| Canary | 段階的にトラフィック移行 | 通常リリース |
| Shadow | 新モデルで並行推論（結果は破棄） | A/Bテスト前 |

### 6.2 Seldon Core デプロイメント

```yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: medical-diagnosis-model
  namespace: mlops
spec:
  predictors:
    - name: default
      replicas: 3
      graph:
        name: classifier
        implementation: SKLEARN_SERVER
        modelUri: s3://medical-ai-models/diagnosis/v1.0.0
      componentSpecs:
        - spec:
            containers:
              - name: classifier
                resources:
                  requests:
                    memory: "2Gi"
                    cpu: "1"
                  limits:
                    memory: "4Gi"
                    cpu: "2"
      traffic: 100

    # Canary デプロイメント
    - name: canary
      replicas: 1
      graph:
        name: classifier
        implementation: SKLEARN_SERVER
        modelUri: s3://medical-ai-models/diagnosis/v1.1.0
      traffic: 0  # 段階的に増加
```

### 6.3 モデルバージョン管理

| 環境 | モデルバージョン | ステータス |
|------|----------------|-----------|
| Production | v1.0.0 | Active |
| Staging | v1.1.0 | Testing |
| Development | v1.2.0-dev | Development |

---

## 7. モデル監視

### 7.1 監視メトリクス

#### パフォーマンスメトリクス
| メトリクス | 閾値 | アラート条件 |
|-----------|------|-------------|
| Latency P99 | 200ms | > 500ms |
| Throughput | 1000 req/s | < 500 req/s |
| Error Rate | 0.1% | > 1% |

#### モデル品質メトリクス
| メトリクス | 閾値 | アラート条件 |
|-----------|------|-------------|
| Accuracy | 95% | < 90% |
| Data Drift Score | 0.1 | > 0.3 |
| Prediction Drift | 0.05 | > 0.2 |

### 7.2 データドリフト検出

```python
from evidently.metrics import DataDriftPreset
from evidently.report import Report

# ドリフトレポート生成
drift_report = Report(metrics=[
    DataDriftPreset(),
])

drift_report.run(
    reference_data=training_data,
    current_data=production_data,
)

# ドリフトスコア取得
drift_score = drift_report.as_dict()['metrics'][0]['result']['drift_share']

if drift_score > 0.3:
    send_alert("High data drift detected!")
```

### 7.3 モデル再学習トリガー

| トリガー | 条件 | アクション |
|---------|------|----------|
| 定期再学習 | 毎週日曜 | 自動実行 |
| ドリフト検出 | drift_score > 0.3 | アラート + 手動判断 |
| パフォーマンス低下 | accuracy < 90% | アラート + 手動判断 |
| 新データ蓄積 | 10万件以上 | 自動実行 |

---

## 8. CI/CD パイプライン

### 8.1 GitHub Actions ワークフロー

```yaml
name: MLOps Pipeline

on:
  push:
    branches: [main]
    paths:
      - 'models/**'
      - 'pipelines/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run unit tests
        run: pytest tests/unit/

      - name: Run data validation
        run: python scripts/validate_data.py

  train:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Trigger training pipeline
        run: |
          aws stepfunctions start-execution \
            --state-machine-arn ${{ secrets.TRAINING_STATE_MACHINE }}

  deploy-staging:
    needs: train
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Deploy to staging
        run: |
          kubectl apply -f k8s/staging/seldon-deployment.yaml

      - name: Run integration tests
        run: pytest tests/integration/

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy canary
        run: |
          kubectl apply -f k8s/production/seldon-deployment-canary.yaml

      - name: Monitor canary
        run: python scripts/monitor_canary.py --duration 30m

      - name: Promote to production
        run: |
          kubectl apply -f k8s/production/seldon-deployment.yaml
```

---

## 9. 運用手順

### 9.1 日常運用タスク

| タスク | 頻度 | 担当 |
|--------|------|------|
| パイプライン実行確認 | 日次 | 自動 |
| ドリフトモニタリング | 日次 | 自動 |
| モデルパフォーマンス確認 | 週次 | MLエンジニア |
| 再学習実行 | 週次 | 自動 |

### 9.2 障害対応フロー

```
1. アラート発生
   ↓
2. 影響範囲確認
   - 推論サービス停止？
   - データパイプライン停止？
   ↓
3. 一時対応
   - 前バージョンへロールバック
   - トラフィック制限
   ↓
4. 根本原因分析
   ↓
5. 恒久対応
   ↓
6. ポストモーテム作成
```

---

## 10. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
