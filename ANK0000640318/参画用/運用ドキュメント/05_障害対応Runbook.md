# 障害対応Runbook

## 1. 概要

### 1.1 目的
本ドキュメントは、障害発生時の対応手順を定義する。

### 1.2 インシデント重要度

| 重要度 | 定義 | 対応時間 | 例 |
|--------|------|---------|-----|
| P1 | サービス全停止 | 即時 | 決済不可、全API停止 |
| P2 | 主要機能停止 | 15分以内 | 決済遅延、一部API停止 |
| P3 | 軽微な影響 | 1時間以内 | 一部エラー、性能低下 |
| P4 | 影響なし | 翌営業日 | 監視アラートのみ |

---

## 2. 初動対応フロー

### 2.1 全体フロー

```
┌─────────────────────────────────────────────────────────────────┐
│                    インシデント対応フロー                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │アラート   │───>│初動確認  │───>│影響特定  │───>│対応判断  │  │
│  │発報      │    │(5分以内) │    │         │    │         │  │
│  └──────────┘    └──────────┘    └──────────┘    └────┬─────┘  │
│                                                        │         │
│                    ┌───────────────────────────────────┤         │
│                    │                                   │         │
│                    ▼                                   ▼         │
│         ┌──────────────────┐              ┌──────────────────┐  │
│         │   一時対応        │              │   経過観察       │  │
│         │  (ロールバック等) │              │  (監視継続)      │  │
│         └────────┬─────────┘              └──────────────────┘  │
│                  │                                               │
│                  ▼                                               │
│         ┌──────────────────┐                                    │
│         │   根本原因調査    │                                    │
│         └────────┬─────────┘                                    │
│                  │                                               │
│                  ▼                                               │
│         ┌──────────────────┐                                    │
│         │   恒久対応        │                                    │
│         └────────┬─────────┘                                    │
│                  │                                               │
│                  ▼                                               │
│         ┌──────────────────┐                                    │
│         │  ポストモーテム   │                                    │
│         └──────────────────┘                                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 初動確認チェックリスト

```bash
# 1. サービス状態確認
kubectl get pods -n production
kubectl get events -n production --sort-by='.lastTimestamp' | head -20

# 2. エラー率確認（Grafana or PromQL）
# sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# 3. 直近のデプロイ確認
kubectl rollout history deployment/payment-api -n production

# 4. 外部依存サービス確認
# - Cloud SQL: GCP Console
# - Redis: Memorystore Console
# - 外部API: ステータスページ確認
```

---

## 3. 障害別Runbook

### 3.1 Payment API エラー率上昇

**アラート**: `PaymentAPIHighErrorRate`

#### 確認手順

```bash
# 1. エラーログ確認
kubectl logs -l app=payment-api -n production --tail=100 | grep ERROR

# 2. エラー詳細確認（Cloud Logging）
# severity="ERROR" AND resource.labels.namespace_name="production"

# 3. エラーの内訳確認
# - 5xx: サーバーエラー → 内部問題
# - 4xx: クライアントエラー → リクエスト問題
# - Timeout: タイムアウト → 外部依存or負荷

# 4. 直近のデプロイ確認
kubectl rollout history deployment/payment-api -n production
```

#### 対応手順

**原因：直近のデプロイ**
```bash
# ロールバック
kubectl rollout undo deployment/payment-api -n production
kubectl rollout status deployment/payment-api -n production
```

**原因：DB接続エラー**
```bash
# DB接続確認
kubectl exec -it <pod-name> -n production -- \
  psql -h <db-host> -U <user> -d <database> -c "SELECT 1"

# 接続数確認
# GCP Console → Cloud SQL → Connections

# 対応：接続プールリセット
kubectl rollout restart deployment/payment-api -n production
```

**原因：外部API障害**
```bash
# 外部API確認
kubectl exec -it <pod-name> -n production -- \
  curl -v https://external-api.example.com/health

# 対応：サーキットブレーカー確認/手動切り替え
```

---

### 3.2 Payment API 高レイテンシ

**アラート**: `PaymentAPIHighLatency`

#### 確認手順

```bash
# 1. 現在のレイテンシ確認
# Grafana: Payment API Latency Dashboard

# 2. 遅いリクエストの特定
# Cloud Logging: jsonPayload.duration_ms > 100

# 3. DB クエリ性能確認
# GCP Console → Cloud SQL → Query Insights

# 4. Pod リソース確認
kubectl top pods -n production
```

#### 対応手順

**原因：DB クエリ遅延**
```bash
# スロークエリ特定（Cloud SQL Query Insights）
# 対応：
# - インデックス追加（要検討）
# - クエリ最適化（要検討）
# - 一時的にレプリカへの読み取り分散
```

**原因：Pod リソース不足**
```bash
# スケールアウト
kubectl scale deployment/payment-api --replicas=10 -n production

# リソース制限確認
kubectl describe deployment payment-api -n production | grep -A5 Resources
```

**原因：外部API遅延**
```bash
# タイムアウト設定確認
# 対応：
# - タイムアウト値調整
# - キャッシュ活用
# - フォールバック有効化
```

---

### 3.3 Pod CrashLoopBackOff

**アラート**: `PodRestartingTooMuch`

#### 確認手順

```bash
# 1. Pod状態確認
kubectl get pods -n production | grep -v Running
kubectl describe pod <pod-name> -n production

# 2. ログ確認
kubectl logs <pod-name> -n production
kubectl logs <pod-name> -n production --previous

# 3. イベント確認
kubectl get events -n production --field-selector involvedObject.name=<pod-name>
```

#### 対応手順

**原因：OOMKilled**
```bash
# メモリ制限確認
kubectl describe pod <pod-name> -n production | grep -A5 Limits

# 対応：メモリ制限増加
kubectl patch deployment payment-api -n production -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"payment-api","resources":{"limits":{"memory":"2Gi"}}}]}}}}'
```

**原因：設定エラー**
```bash
# ConfigMap/Secret確認
kubectl get configmap -n production
kubectl get secret -n production

# 対応：設定修正後再デプロイ
kubectl rollout restart deployment/payment-api -n production
```

**原因：起動チェック失敗**
```bash
# Probe設定確認
kubectl describe deployment payment-api -n production | grep -A10 Probe

# 対応：
# - Probe設定の調整
# - 起動時間の延長（initialDelaySeconds）
```

---

### 3.4 データベース接続エラー

**アラート**: `DatabaseConnectionErrors`

#### 確認手順

```bash
# 1. Cloud SQL状態確認
# GCP Console → Cloud SQL → Overview

# 2. 接続数確認
# GCP Console → Cloud SQL → Connections

# 3. アプリケーションログ確認
kubectl logs -l app=payment-api -n production | grep -i "database\|connection\|sql"

# 4. ネットワーク確認
kubectl exec -it <pod-name> -n production -- nc -zv <db-host> 5432
```

#### 対応手順

**原因：接続数上限**
```bash
# 対応：接続数設定確認
# GCP Console → Cloud SQL → Edit → Connections

# アプリケーション側の接続プール設定確認
# - max_connections
# - idle_timeout
```

**原因：Cloud SQL障害**
```bash
# GCP ステータス確認
# https://status.cloud.google.com/

# フェイルオーバー実行（HA構成の場合）
gcloud sql instances failover <instance-name>

# リードレプリカへの切り替え（読み取りのみ）
```

**原因：ネットワーク問題**
```bash
# VPC Connector確認
gcloud compute networks vpc-access connectors describe <connector-name> --region=asia-northeast1

# Private Service Connection確認
gcloud services vpc-peerings list --network=<vpc-name>
```

---

### 3.5 外部API障害

**アラート**: `ExternalAPIErrors`

#### 確認手順

```bash
# 1. 外部APIステータス確認
curl -v https://external-api.example.com/health

# 2. アプリケーションログ確認
kubectl logs -l app=payment-api -n production | grep "external-api"

# 3. サーキットブレーカー状態確認
# アプリケーション管理画面 or メトリクス
```

#### 対応手順

**短期対応**
```bash
# フォールバック有効化（アプリケーション設定）
kubectl set env deployment/payment-api -n production EXTERNAL_API_FALLBACK=true

# リトライ設定調整
kubectl set env deployment/payment-api -n production EXTERNAL_API_TIMEOUT=5s
```

**長期対応**
- 外部APIプロバイダーへの連絡
- SLA確認と補償交渉
- 代替APIの検討

---

## 4. エスカレーション

### 4.1 エスカレーション基準

| 状況 | 連絡先 | 手段 |
|------|--------|------|
| P1インシデント | VP/CTO | 電話 + Slack |
| 30分以上未解決 | Manager | Slack + 電話 |
| セキュリティ関連 | Security Team | 即時連絡 |
| 顧客影響大 | Customer Success | Slack |

### 4.2 連絡先一覧

| 役割 | 連絡先 | 備考 |
|------|--------|------|
| On-call Primary | PagerDuty | 自動通知 |
| Platform Team | #platform-oncall | Slack |
| DB Admin | #dba-oncall | Slack |
| Security | security@example.com | Email + Slack |

---

## 5. ポストモーテム

### 5.1 テンプレート

```markdown
# ポストモーテム: [インシデント名]

## 概要
- **発生日時**: YYYY-MM-DD HH:MM - HH:MM (JST)
- **影響時間**: XX分
- **重要度**: P1/P2/P3/P4
- **影響範囲**: [影響を受けたサービス・ユーザー数]

## タイムライン
| 時刻 | イベント |
|------|---------|
| HH:MM | アラート発報 |
| HH:MM | 初動対応開始 |
| HH:MM | 原因特定 |
| HH:MM | 一時対応完了 |
| HH:MM | 復旧完了 |

## 根本原因
[根本原因の詳細説明]

## 影響
- ユーザー影響: XXX件のリクエストが失敗
- ビジネス影響: 推定XXX円の損失
- SLO影響: エラーバジェットXX%消費

## 対応内容
### 一時対応
- [実施した一時対応]

### 恒久対応
| # | アクション | 担当 | 期限 | ステータス |
|---|----------|------|------|----------|
| 1 | | | | |
| 2 | | | | |

## 教訓
### うまくいったこと
-

### 改善すべきこと
-

## 参加者
- [対応者名]
```

### 5.2 ポストモーテム実施基準

| 条件 | ポストモーテム |
|------|--------------|
| P1インシデント | 必須（48時間以内） |
| P2インシデント | 必須（1週間以内） |
| エラーバジェット50%以上消費 | 必須 |
| 30分以上の障害 | 推奨 |

---

## 6. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
