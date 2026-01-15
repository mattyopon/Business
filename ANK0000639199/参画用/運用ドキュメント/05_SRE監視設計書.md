# SRE監視・ログ・アラート設計書

## 1. 概要

### 1.1 目的
本ドキュメントは、システムの監視、ログ収集、アラート設計を定義する。

### 1.2 SLI/SLO定義

| サービス | SLI | SLO | 測定方法 |
|---------|-----|-----|----------|
| API Server | 可用性 | 99.9% | 成功リクエスト / 総リクエスト |
| API Server | レイテンシ（P99） | < 200ms | Prometheus histogram |
| ML Inference | 推論成功率 | 99.5% | 成功推論 / 総推論 |
| Database | 接続成功率 | 99.99% | 成功接続 / 総接続試行 |

### 1.3 エラーバジェット

```
月間エラーバジェット = (1 - SLO) × 月間総分
例: API Server (SLO 99.9%)
   = (1 - 0.999) × 43,200分（30日）
   = 43.2分/月
```

---

## 2. 監視アーキテクチャ

### 2.1 全体構成

```
┌─────────────────────────────────────────────────────────────────┐
│                     Monitoring Architecture                      │
│                                                                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐        │
│  │ Application │────>│ Prometheus  │────>│   Grafana   │        │
│  │   Metrics   │     │             │     │             │        │
│  └─────────────┘     └──────┬──────┘     └─────────────┘        │
│                              │                                    │
│  ┌─────────────┐     ┌──────▼──────┐     ┌─────────────┐        │
│  │ Application │────>│ CloudWatch  │────>│    SNS      │───> Slack│
│  │    Logs     │     │    Logs     │     │   Alarms    │   PagerDuty│
│  └─────────────┘     └─────────────┘     └─────────────┘        │
│                                                                   │
│  ┌─────────────┐     ┌─────────────┐                             │
│  │   X-Ray     │────>│  Trace      │                             │
│  │   (APM)     │     │  Analysis   │                             │
│  └─────────────┘     └─────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 使用ツール

| カテゴリ | ツール | 用途 |
|---------|--------|------|
| メトリクス収集 | Prometheus | アプリ・インフラメトリクス |
| メトリクス収集 | CloudWatch | AWSサービスメトリクス |
| 可視化 | Grafana | ダッシュボード |
| ログ収集 | CloudWatch Logs | ログ集約 |
| ログ分析 | CloudWatch Logs Insights | ログ検索・分析 |
| トレーシング | AWS X-Ray | 分散トレーシング |
| アラート | CloudWatch Alarms + SNS | 通知 |
| インシデント管理 | PagerDuty | オンコール管理 |

---

## 3. メトリクス設計

### 3.1 収集メトリクス一覧

#### アプリケーションメトリクス

| メトリクス名 | 型 | 説明 | ラベル |
|-------------|-----|------|--------|
| http_requests_total | Counter | HTTPリクエスト数 | method, path, status |
| http_request_duration_seconds | Histogram | リクエスト処理時間 | method, path |
| ml_inference_total | Counter | 推論リクエスト数 | model, status |
| ml_inference_duration_seconds | Histogram | 推論処理時間 | model |
| active_connections | Gauge | アクティブ接続数 | - |

#### インフラメトリクス

| メトリクス名 | 型 | 説明 | 取得元 |
|-------------|-----|------|--------|
| container_cpu_usage_seconds_total | Counter | CPU使用時間 | cAdvisor |
| container_memory_usage_bytes | Gauge | メモリ使用量 | cAdvisor |
| node_cpu_seconds_total | Counter | ノードCPU使用時間 | Node Exporter |
| node_memory_MemAvailable_bytes | Gauge | 利用可能メモリ | Node Exporter |

### 3.2 Prometheus 設定

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

  - job_name: 'kubernetes-service-endpoints'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

### 3.3 アプリケーションメトリクス実装例

```python
# Python (FastAPI + prometheus_client)
from prometheus_client import Counter, Histogram, generate_latest
from fastapi import FastAPI, Request
import time

app = FastAPI()

# メトリクス定義
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'path', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'path'],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    REQUEST_COUNT.labels(
        method=request.method,
        path=request.url.path,
        status=response.status_code
    ).inc()

    REQUEST_LATENCY.labels(
        method=request.method,
        path=request.url.path
    ).observe(duration)

    return response

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type="text/plain")
```

---

## 4. ログ設計

### 4.1 ログレベル定義

| レベル | 用途 | 例 |
|--------|------|-----|
| ERROR | 即座に対応が必要なエラー | DB接続失敗、API 5xx |
| WARN | 注意が必要だが即時対応不要 | リトライ成功、遅延発生 |
| INFO | 正常な業務処理の記録 | リクエスト処理完了 |
| DEBUG | 開発・デバッグ用（本番では無効） | 変数値、処理詳細 |

### 4.2 ログフォーマット（構造化ログ）

```json
{
  "timestamp": "2026-01-15T10:30:00.000Z",
  "level": "INFO",
  "logger": "api.handlers",
  "message": "Request processed successfully",
  "trace_id": "abc123xyz",
  "span_id": "def456",
  "request_id": "req-001",
  "user_id": "user-123",
  "method": "POST",
  "path": "/api/v1/predict",
  "status_code": 200,
  "duration_ms": 150,
  "extra": {
    "model_version": "1.2.0",
    "prediction_confidence": 0.95
  }
}
```

### 4.3 ログ実装例

```python
import structlog
import logging

# structlog設定
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# 使用例
logger.info(
    "request_processed",
    method="POST",
    path="/api/v1/predict",
    status_code=200,
    duration_ms=150,
    user_id="user-123"
)
```

### 4.4 CloudWatch Logs Insights クエリ例

```sql
-- エラーログ検索
fields @timestamp, @message
| filter level = "ERROR"
| sort @timestamp desc
| limit 100

-- レイテンシ分析
fields @timestamp, duration_ms, path
| filter duration_ms > 1000
| stats avg(duration_ms) as avg_latency,
        max(duration_ms) as max_latency,
        count(*) as count
  by path

-- ユーザー別リクエスト数
fields @timestamp, user_id
| stats count(*) as request_count by user_id
| sort request_count desc
| limit 20
```

---

## 5. アラート設計

### 5.1 アラートルール

```yaml
# alert_rules.yml
groups:
  - name: api-server
    rules:
      # 高エラー率
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) /
          sum(rate(http_requests_total[5m])) > 0.01
        for: 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "High error rate (> 1%)"
          description: "Error rate is {{ $value | humanizePercentage }}"
          runbook_url: "https://wiki.example.com/runbooks/high-error-rate"

      # 高レイテンシ
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 0.5
        for: 5m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High latency (P99 > 500ms)"
          description: "P99 latency is {{ $value | humanizeDuration }}"

      # Pod再起動
      - alert: PodRestartingTooMuch
        expr: |
          increase(kube_pod_container_status_restarts_total[1h]) > 3
        for: 10m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "Pod restarting frequently"

  - name: ml-inference
    rules:
      # 推論エラー
      - alert: MLInferenceErrors
        expr: |
          sum(rate(ml_inference_total{status="error"}[5m])) /
          sum(rate(ml_inference_total[5m])) > 0.005
        for: 5m
        labels:
          severity: critical
          team: ml
        annotations:
          summary: "ML inference error rate high"

      # 推論レイテンシ
      - alert: MLInferenceSlowdown
        expr: |
          histogram_quantile(0.99,
            sum(rate(ml_inference_duration_seconds_bucket[5m])) by (le, model)
          ) > 1.0
        for: 5m
        labels:
          severity: warning
          team: ml
        annotations:
          summary: "ML inference slowdown detected"
```

### 5.2 アラート重要度

| Severity | 対応時間 | 通知先 | 例 |
|----------|---------|--------|-----|
| critical | 即時 | PagerDuty + Slack | サービス停止、高エラー率 |
| warning | 30分以内 | Slack | レイテンシ上昇、リソース逼迫 |
| info | 翌営業日 | Slack | 情報通知 |

### 5.3 Alertmanager設定

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/xxx'

route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
    - match:
        severity: warning
      receiver: 'slack-warning'

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
        send_resolved: true

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: '<pagerduty-key>'
    slack_configs:
      - channel: '#alerts-critical'
        send_resolved: true

  - name: 'slack-warning'
    slack_configs:
      - channel: '#alerts-warning'
        send_resolved: true
```

---

## 6. ダッシュボード設計

### 6.1 ダッシュボード一覧

| ダッシュボード | 対象者 | 内容 |
|---------------|--------|------|
| Executive Summary | 経営層 | SLO達成率、可用性 |
| Service Overview | SRE/DevOps | 全サービス概要 |
| API Server | 開発者 | API詳細メトリクス |
| ML Inference | MLエンジニア | 推論パフォーマンス |
| Infrastructure | インフラ | リソース使用状況 |

### 6.2 SREダッシュボード構成

```
┌─────────────────────────────────────────────────────────────────┐
│                     Service Overview Dashboard                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │ Availability│ │Error Budget │ │   Latency   │ │ Throughput│ │
│  │   99.95%    │ │  70% left   │ │  P99: 150ms │ │  1.2k/s   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Request Rate                    │  Error Rate                   │
│  [Graph: 24h trend]              │  [Graph: 24h trend]           │
├─────────────────────────────────────────────────────────────────┤
│  Latency Distribution            │  Active Incidents             │
│  [Histogram]                     │  [Alert list]                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. インシデント対応

### 7.1 対応フロー

```
1. アラート発報
   ↓
2. 一次確認（5分以内）
   - 影響範囲の特定
   - ダッシュボード確認
   ↓
3. インシデント宣言（必要に応じて）
   - Slackチャンネル作成
   - 関係者召集
   ↓
4. 一時対応
   - ロールバック
   - スケールアウト
   - 機能停止
   ↓
5. 根本原因分析
   ↓
6. 恒久対応
   ↓
7. ポストモーテム作成
```

### 7.2 Runbook テンプレート

```markdown
# Runbook: High Error Rate

## アラート条件
- エラー率 > 1%（5分間継続）

## 影響
- ユーザーへの影響: API呼び出しの一部が失敗
- ビジネス影響: サービス品質低下

## 確認手順
1. Grafanaダッシュボードでエラー率確認
2. CloudWatch Logsでエラーログ確認
3. 直近のデプロイ有無確認

## 対応手順
1. 直近のデプロイがあればロールバック
2. 特定のエンドポイントのみエラーの場合、該当機能を一時停止
3. DBやRedis等のバックエンド障害の場合、それぞれの対応手順を実施

## エスカレーション
- 30分以内に改善しない場合: Tech Lead に連絡
- サービス全停止の場合: 即座にVPに連絡
```

### 7.3 ポストモーテム テンプレート

```markdown
# ポストモーテム: [インシデント名]

## 概要
- 日時: YYYY-MM-DD HH:MM - HH:MM (JST)
- 影響時間: XX分
- 影響範囲: [影響を受けたサービス/ユーザー]
- 重要度: P1/P2/P3

## タイムライン
- HH:MM アラート発報
- HH:MM 一次対応開始
- HH:MM 根本原因特定
- HH:MM 復旧完了

## 根本原因
[根本原因の説明]

## 影響
- ユーザー影響: XXX件のリクエストが失敗
- 収益影響: 推定XXX円

## 教訓
### うまくいったこと
-

### 改善すべきこと
-

## アクションアイテム
| # | アクション | 担当 | 期限 |
|---|----------|------|------|
| 1 | | | |
| 2 | | | |
```

---

## 8. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
