# 06. 障害対応 Runbook

## 1. 目的

検索システムの典型障害シナリオに対する一次対応 / 復旧手順を、当番 SRE が 15分で着手できる粒度で定義する。

## 2. 障害レベル

| レベル | 影響 | 例 | エスカレ |
|--------|------|----|---------|
| Sev1 | サービス全停止 / 重大セキュリティ | API 全停止、データ漏えい疑い | 即時 全関係者 |
| Sev2 | 機能一部停止 / SLO 違反継続 | 検索遅延 p95 > 2s 30分継続 | SRE 責任者 + 案件責任者 |
| Sev3 | 単機能の劣化 / 兆候 | クラスタ Yellow、4xx 急増 | SRE 当番のみ |
| Sev4 | 観測値の異常 (ユーザー影響なし) | コスト急増、警告ログ | 翌営業日 |

## 3. 初動共通 (全レベル共通)

1. **検知**: PagerDuty / Slack で受信。タイムスタンプを記録
2. **記録チャンネル**: Slack `#incident-search-<yyyymmdd-hhmm>` を作成し関係者を招集
3. **状況整理**: 5W1H で第一報を 5分以内に投稿 (誰が / いつから / どの API / どんな症状 / 影響範囲不明可)
4. **影響確認**: 外形監視 (Route 53 Health Check) と CloudWatch ダッシュボード `search-overview` で再現性確認
5. **広報判断**: ユーザー向けステータスページ更新が必要か Sev1/2 で判断

## 4. シナリオ別フロー

### 4.1 OpenSearch Cluster Red

**症状**: `ClusterStatus.red` > 0 Critical

```bash
# 1. クラスタ状態確認 (SSM Session Manager 経由の踏み台 or VPN)
curl -s --aws-sigv4 ... https://<endpoint>/_cluster/health?pretty
curl -s --aws-sigv4 ... https://<endpoint>/_cat/indices?v

# 2. unassigned shard の調査
curl -s --aws-sigv4 ... https://<endpoint>/_cluster/allocation/explain?pretty
```

**対応**:
- `unassigned` shard あり: AWS サポート起票 (Sev2 以上)
- ノード障害: Service Health Dashboard 確認、必要なら blue/green deploy で交換
- ストレージ枯渇: 古い index を `_delete` または `cold-warm tier` に移動

### 4.2 検索遅延 / p95 > 1s

**症状**: `SearchLatency` p95 > 1000ms 10分継続

```bash
# 1. スローログ確認
fields @timestamp, took, query.match, request_path
| filter @logStream like /search-slowlog/
| sort @timestamp desc
| limit 50
```

**対応**:
- 高負荷クエリ: クエリ DSL を最適化 (フィールド絞り込み、`size` 削減、`stored_fields` 利用)
- shard 偏り: `_cat/shards` で容量確認、必要なら reindex で再分散
- JVMヒープ圧迫: `JVMMemoryPressure` > 75% なら scale up / インスタンス交換検討

### 4.3 API Gateway 5xx 増加

**症状**: `5XXError` > 1% / 5min

```bash
# 1. CloudWatch Logs Insights で原因切り分け
fields @timestamp, status, requestPath, integrationLatency
| filter status >= 500
| stats count() by status, requestPath
```

**対応**:
- Lambda タイムアウト: `Duration` p95 と timeout を比較。timeout 引き上げまたは処理分割
- Lambda エラー: トレースで例外確認 (X-Ray)
- OpenSearch 由来: 4.1 / 4.2 へ

### 4.4 Cognito 認証エラー急増

**症状**: `SignInSuccesses` 急減、`TokenRefreshThrottles` > 0

**対応**:
- App Client 設定変更が直近にあれば revert
- Service Health Dashboard で AWS 側障害確認
- ユーザー側 (アプリバージョン) 不具合の可能性をフロント担当に共有

### 4.5 EBS / ストレージ枯渇

**症状**: `FreeStorageSpace` < 10%

**対応**:
- 緊急: 古い index を削除 / アーカイブ
- 中期: EBS 拡張 (blue/green deploy)、Index Lifecycle Policy 見直し

### 4.6 セキュリティインシデント疑い

- まず**停止せず証跡保全**: VPC Flow Logs, CloudTrail, GuardDuty Findings をスナップショット
- 不正アクセス: 該当 IAM Role / Cognito User の Access Key / Token を即座に revoke
- 詳細フローは `05_セキュリティガイドライン.md` の連絡網へ

## 5. 復旧後

| 項目 | 期限 |
|------|------|
| ステータスページ更新 (復旧) | 復旧から 15分以内 |
| 関係者報告 (一次まとめ) | 復旧から 2時間以内 |
| ポストモーテム (5 Whys + Action Items) | 7営業日以内 |
| Runbook 改訂 (再発防止反映) | ポストモーテム承認後 7営業日以内 |

## 6. 連絡網

> 本リポジトリは雛形のため、参画時に契約書に基づき以下を確定すること。プレースホルダのまま運用しないこと。

| ロール | 一次連絡 | 二次連絡 | 備考 |
|--------|---------|---------|------|
| SRE 当番 | (参画時に設定) | (参画時に設定) | PagerDuty で自動アサイン |
| 案件責任者 | (参画時に設定) | - | Sev1/2 必須通知 |
| クライアント窓口 | (参画時に設定) | (参画時に設定) | 営業時間内 / 時間外を分けて記載 |
| AWS サポート | Business/Enterprise Support 経由 | - | Sev1 起票時のみ |

## 7. 関連資料

- [01_AWSインフラ設計書.md](01_AWSインフラ設計書.md)
- [02_OpenSearch運用ガイド.md](02_OpenSearch運用ガイド.md)
- [03_API-Gateway設計書.md](03_API-Gateway設計書.md)
- [04_監視設計書.md](04_監視設計書.md)
- [05_セキュリティガイドライン.md](05_セキュリティガイドライン.md)
