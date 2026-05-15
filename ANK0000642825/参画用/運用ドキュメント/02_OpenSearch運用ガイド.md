# OpenSearch運用ガイド

## 1. 概要

### 1.1 目的
本ドキュメントは、Amazon OpenSearch Serviceの運用手順を定義する。

### 1.2 クラスター構成

| 項目 | 本番環境 | 開発環境 |
|------|---------|---------|
| ドメイン名 | search-prod | search-dev |
| エンジンバージョン | OpenSearch 2.11 | OpenSearch 2.11 |
| インスタンスタイプ | r6g.large.search | t3.medium.search |
| インスタンス数 | 3 | 1 |
| EBSボリューム | 500GB gp3 | 100GB gp3 |

---

## 2. 接続方法

### 2.1 エンドポイント確認

```bash
aws opensearch describe-domain --domain-name search-prod \
  --query 'DomainStatus.Endpoint' --output text
```

### 2.2 curl での SigV4 署名アクセス（IAM 認証 / Managed Service ドメイン）

OpenSearch Service (Managed) は IAM 認証ドメインの場合、リクエストに **AWS SigV4 署名** を付ける必要がある。Serverless ではない（`aws opensearch-serverless` は対象外）。

#### 方法 A. `awscurl` を使う（推奨）

```bash
# 事前準備
pip install awscurl
export AWS_PROFILE=search-ops
export ENDPOINT=https://search-prod-xxxx.ap-northeast-1.es.amazonaws.com

# クラスタヘルス
awscurl --region ap-northeast-1 --service es \
  -X GET "${ENDPOINT}/_cluster/health?pretty"

# インデックス一覧
awscurl --region ap-northeast-1 --service es \
  -X GET "${ENDPOINT}/_cat/indices?v"
```

#### 方法 B. curl + `--aws-sigv4` (curl 7.75+)

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # 短命トークン推奨 (IAM Identity Center / AssumeRole)
export ENDPOINT=search-prod-xxxx.ap-northeast-1.es.amazonaws.com

curl -s \
  --aws-sigv4 "aws:amz:ap-northeast-1:es" \
  --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" \
  -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" \
  "https://${ENDPOINT}/_cluster/health?pretty"
```

#### 方法 C. Python (`opensearch-py` + `requests-aws4auth`)

```python
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import boto3

region = "ap-northeast-1"
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    "es",
    session_token=credentials.token,
)

client = OpenSearch(
    hosts=[{"host": "search-prod-xxxx.ap-northeast-1.es.amazonaws.com", "port": 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
)

print(client.cluster.health())
```

> **注意**: `http_auth=('username','password')` のような Basic 認証はマスター内部DB (`internal_user_database_enabled=true`) を有効化したドメインのみ。本案件は IAM Role を `master_user` にする想定 (`terraform-aws-search/main.tf` 参照) なので、Basic 認証は使えない。

### 2.3 OpenSearch Dashboards

OpenSearch Service の Dashboards に Cognito 連携を行う場合、**User Pool だけでなく Identity Pool と CognitoAccess 用 IAM ロール、OpenSearch ドメインの Cognito 設定をセットで構成する必要がある**（User Pool 単独では Dashboards にアクセスできない）。

| コンポーネント | 役割 | Terraform リソース (例) |
|--------------|------|------------------------|
| **Cognito User Pool** | ユーザー認証 (パスワード／SSO / SAML / OIDC IdP)。`auth.your-domain.com` のホストドメイン (User Pool Domain) を必ず作成 | `aws_cognito_user_pool`, `aws_cognito_user_pool_domain` |
| **Cognito Identity Pool** | User Pool で認証された identity に AWS の一時クレデンシャルを払い出す。Dashboards から OpenSearch API を叩く際に **必須** | `aws_cognito_identity_pool`, `aws_cognito_identity_pool_roles_attachment` |
| **CognitoAccess (Authenticated) IAM Role** | Identity Pool が払い出す認証済みロール。OpenSearch のドメインアクセスポリシーで principal として許可する | `aws_iam_role` (trust: `cognito-identity.amazonaws.com`, condition: 該当 Identity Pool ID) |
| **AmazonOpenSearchServiceCognitoAccess IAM Role** | OpenSearch ドメインが Cognito を呼び出すためのサービスロール (AWS マネージドポリシー `AmazonOpenSearchServiceCognitoAccess` を attach) | `aws_iam_role` (trust: `es.amazonaws.com`) |
| **OpenSearch ドメインの Cognito 設定** | ドメイン側で User Pool ID / Identity Pool ID / 上記サービスロールを指定 | `aws_opensearch_domain.cognito_options` (`enabled = true`, `user_pool_id`, `identity_pool_id`, `role_arn`) |
| **OpenSearch ドメインアクセスポリシー** | 認証済み IAM ロール (CognitoAccess Authenticated Role) からの `es:ESHttp*` を許可 | `aws_opensearch_domain.access_policies` (Statement で Principal: 認証済みロール ARN) |

- URL: `https://<endpoint>/_dashboards`
- 認証: 上記 5 コンポーネントすべて構成済みであることを前提とした、Cognito User Pool 経由のフェデレーションログイン
- FGAC (Fine Grained Access Control) を有効化している場合は、上記の CognitoAccess Authenticated Role を OpenSearch 内部のロール (`all_access` または `kibana_user` 等) にもマッピングする (`/_plugins/_security/api/rolesmapping/<role>` への PUT)
- 検証参照: `技術検証/terraform-aws-search/main.tf` の `aws_cognito_*` および `aws_opensearch_domain.cognito_options` ブロックと整合させる

---

## 3. インデックス管理

### 3.1 インデックス一覧確認

```bash
awscurl --region ap-northeast-1 --service es -XGET "https://<endpoint>/_cat/indices?v"
# または: curl --aws-sigv4 "aws:amz:ap-northeast-1:es" --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" -XGET "https://<endpoint>/_cat/indices?v"
```

### 3.2 インデックス作成

```json
PUT /products
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "properties": {
      "name": { "type": "text" },
      "category": { "type": "keyword" }
    }
  }
}
```

### 3.3 インデックス削除

```bash
awscurl --region ap-northeast-1 --service es -XDELETE "https://<endpoint>/products"
# または: curl --aws-sigv4 "aws:amz:ap-northeast-1:es" --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" -XDELETE "https://<endpoint>/products"
```

### 3.4 インデックスライフサイクル管理（ISM）

```json
PUT /_plugins/_ism/policies/delete_old_logs
{
  "policy": {
    "description": "Delete old log indices",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "30d"
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          { "delete": {} }
        ]
      }
    ]
  }
}
```

---

## 4. クラスター監視

### 4.1 クラスターヘルス確認

```bash
# 前提: 2.2 で説明した SigV4 署名 (awscurl または curl --aws-sigv4) を必ず使う

# クラスター状態
awscurl --region ap-northeast-1 --service es -XGET "https://<endpoint>/_cluster/health?pretty"

# ノード状態
awscurl --region ap-northeast-1 --service es -XGET "https://<endpoint>/_nodes/stats?pretty"

# シャード状態
awscurl --region ap-northeast-1 --service es -XGET "https://<endpoint>/_cat/shards?v"
```

### 4.2 主要メトリクス

| メトリクス | 正常値 | 警告値 |
|-----------|--------|--------|
| ClusterStatus | green | yellow |
| CPUUtilization | < 80% | > 80% |
| JVMMemoryPressure | < 80% | > 80% |
| FreeStorageSpace | > 20% | < 20% |
| SearchLatency | < 100ms | > 500ms |

### 4.3 CloudWatchアラーム設定

```yaml
# Terraform例
resource "aws_cloudwatch_metric_alarm" "opensearch_cpu" {
  alarm_name          = "opensearch-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "OpenSearch CPU usage is high"
  dimensions = {
    DomainName = "search-prod"
  }
}
```

---

## 5. パフォーマンスチューニング

### 5.1 スローログ設定

```json
PUT /products/_settings
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.fetch.warn": "1s",
  "index.indexing.slowlog.threshold.index.warn": "10s"
}
```

### 5.2 シャード設計

| データ量 | シャード数（推奨） |
|---------|------------------|
| 〜10GB | 1 |
| 10GB〜50GB | 3 |
| 50GB〜100GB | 5 |
| 100GB以上 | データ量/50GB |

### 5.3 クエリ最適化

**避けるべきパターン**:
- `match_all` + ソート（ページング用）
- `wildcard` クエリの先頭ワイルドカード
- 大量のOR条件

**推奨パターン**:
- `search_after` によるディープページング
- `filter` コンテキストでのキャッシュ活用
- `keyword` 型でのexact match

---

## 6. バックアップ・リストア

### 6.1 自動スナップショット

Amazon OpenSearch Serviceは1時間ごとに自動スナップショットを取得（14日保持）。

### 6.2 手動スナップショット

```bash
# スナップショットリポジトリ登録
PUT /_snapshot/my-repo
{
  "type": "s3",
  "settings": {
    "bucket": "my-snapshot-bucket",
    "region": "ap-northeast-1",
    "role_arn": "arn:aws:iam::123456789012:role/opensearch-snapshot-role"
  }
}

# スナップショット作成
PUT /_snapshot/my-repo/snapshot-1

# スナップショット確認
GET /_snapshot/my-repo/_all
```

### 6.3 リストア

```bash
# インデックスリストア
POST /_snapshot/my-repo/snapshot-1/_restore
{
  "indices": "products",
  "rename_pattern": "(.+)",
  "rename_replacement": "restored_$1"
}
```

---

## 7. トラブルシューティング

### 7.1 クラスターステータスがyellow

**原因**: レプリカシャードが割り当てられていない

**対処**:
```bash
# 未割り当てシャード確認 (SigV4 必須)
awscurl --region ap-northeast-1 --service es -XGET "https://<endpoint>/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason"

# クラスター再割り当て
POST /_cluster/reroute?retry_failed=true
```

### 7.2 JVMメモリプレッシャーが高い

**原因**: ヒープメモリ不足

**対処**:
- インスタンスタイプをアップグレード
- 不要なインデックスを削除
- シャード数を削減

### 7.3 検索レイテンシが高い

**原因**: クエリ非効率、リソース不足

**対処**:
- スローログでボトルネック特定
- クエリ最適化
- キャッシュ活用

---

## 8. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
