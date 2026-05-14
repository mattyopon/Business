# OpenSearch Demo

OpenSearchの基本操作・クエリ例です。

## 前提条件

- OpenSearch Serviceが起動済み
- エンドポイントにアクセス可能

## 1. インデックス作成

### インデックス定義

```json
PUT /products
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "ja_analyzer": {
          "type": "custom",
          "tokenizer": "kuromoji_tokenizer",
          "filter": [
            "kuromoji_baseform",
            "kuromoji_part_of_speech",
            "ja_stop",
            "kuromoji_stemmer",
            "lowercase"
          ]
        }
      }
    }
  }
}
```

### マッピング定義

```json
PUT /products/_mapping
{
  "properties": {
    "product_id": {
      "type": "keyword"
    },
    "name": {
      "type": "text",
      "analyzer": "ja_analyzer",
      "fields": {
        "keyword": {
          "type": "keyword"
        },
        "suggest": {
          "type": "completion",
          "analyzer": "keyword"
        }
      }
    },
    "description": {
      "type": "text",
      "analyzer": "ja_analyzer"
    },
    "category": {
      "type": "keyword"
    },
    "price": {
      "type": "integer"
    },
    "stock": {
      "type": "integer"
    },
    "tags": {
      "type": "keyword"
    },
    "created_at": {
      "type": "date"
    },
    "updated_at": {
      "type": "date"
    }
  }
}
```

## 2. データ投入

### 単一ドキュメント

```json
POST /products/_doc/1
{
  "product_id": "P001",
  "name": "ワイヤレスイヤホン",
  "description": "高音質Bluetoothワイヤレスイヤホン。ノイズキャンセリング機能付き。",
  "category": "オーディオ",
  "price": 12800,
  "stock": 50,
  "tags": ["Bluetooth", "ノイズキャンセリング", "イヤホン"],
  "created_at": "2025-01-01T00:00:00Z",
  "updated_at": "2025-01-01T00:00:00Z"
}
```

### バルクインサート

```json
POST /products/_bulk
{"index": {"_id": "2"}}
{"product_id": "P002", "name": "スマートウォッチ", "description": "健康管理機能付きスマートウォッチ", "category": "ウェアラブル", "price": 24800, "stock": 30, "tags": ["スマートウォッチ", "健康管理"]}
{"index": {"_id": "3"}}
{"product_id": "P003", "name": "ポータブルスピーカー", "description": "防水仕様のBluetoothスピーカー", "category": "オーディオ", "price": 8900, "stock": 100, "tags": ["Bluetooth", "スピーカー", "防水"]}
```

## 3. 検索クエリ

### 基本検索（match）

```json
GET /products/_search
{
  "query": {
    "match": {
      "name": "ワイヤレス"
    }
  }
}
```

### 複数フィールド検索（multi_match）

```json
GET /products/_search
{
  "query": {
    "multi_match": {
      "query": "Bluetooth 音楽",
      "fields": ["name^2", "description", "tags"]
    }
  }
}
```

### フィルター（bool query）

```json
GET /products/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "description": "Bluetooth"
          }
        }
      ],
      "filter": [
        {
          "term": {
            "category": "オーディオ"
          }
        },
        {
          "range": {
            "price": {
              "gte": 5000,
              "lte": 20000
            }
          }
        }
      ]
    }
  }
}
```

### ファセット検索（Aggregations）

```json
GET /products/_search
{
  "size": 0,
  "aggs": {
    "categories": {
      "terms": {
        "field": "category",
        "size": 10
      }
    },
    "price_ranges": {
      "range": {
        "field": "price",
        "ranges": [
          { "to": 5000 },
          { "from": 5000, "to": 10000 },
          { "from": 10000, "to": 20000 },
          { "from": 20000 }
        ]
      }
    },
    "avg_price": {
      "avg": {
        "field": "price"
      }
    }
  }
}
```

### オートコンプリート

> マッピング側で `name.suggest` を `completion` 型として定義しているため、`name` フィールドをそのまま流用できる。
> データ投入時は `name` を `{ "input": ["..."] }` 形式にせずとも、`name` 文字列がそのまま suggester 入力になる。

```json
GET /products/_search
{
  "suggest": {
    "product_suggest": {
      "prefix": "ワイヤ",
      "completion": {
        "field": "name.suggest",
        "size": 5
      }
    }
  }
}
```

### ハイライト

```json
GET /products/_search
{
  "query": {
    "match": {
      "description": "Bluetooth"
    }
  },
  "highlight": {
    "fields": {
      "description": {
        "pre_tags": ["<em>"],
        "post_tags": ["</em>"]
      }
    }
  }
}
```

## 4. インデックス管理

### インデックス情報確認

```json
GET /products
GET /products/_mapping
GET /products/_settings
GET /products/_stats
```

### インデックス削除

```json
DELETE /products
```

### エイリアス設定

```json
POST /_aliases
{
  "actions": [
    {
      "add": {
        "index": "products_v2",
        "alias": "products"
      }
    },
    {
      "remove": {
        "index": "products_v1",
        "alias": "products"
      }
    }
  ]
}
```

## 5. 運用クエリ

### クラスター状態確認

```bash
GET /_cluster/health
GET /_cluster/stats
GET /_nodes/stats
```

### スローログ確認

```json
PUT /products/_settings
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.fetch.warn": "1s"
}
```

## 6. Python連携例

```python
from opensearchpy import OpenSearch

# 接続
client = OpenSearch(
    hosts=[{'host': 'your-domain.ap-northeast-1.es.amazonaws.com', 'port': 443}],
    http_auth=('username', 'password'),
    use_ssl=True,
    verify_certs=True,
)

# 検索
response = client.search(
    index='products',
    body={
        'query': {
            'match': {
                'name': 'ワイヤレス'
            }
        }
    }
)

for hit in response['hits']['hits']:
    print(hit['_source']['name'])
```

## 関連資料

| 資料 | 説明 |
|------|------|
| [Terraform構築](../terraform-aws-search/) | インフラ構築コード |
| [AWS公式ドキュメント](https://docs.aws.amazon.com/opensearch-service/) | OpenSearch Service公式ドキュメント |
