# Monitoring Demo

金融決済プラットフォーム向け監視・オブザーバビリティのデモです。

## 構成

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                          │
│                                                               │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Grafana    │◄─────│  Prometheus  │                     │
│  │  Port 3000   │      │  Port 9090   │                     │
│  └──────────────┘      └───────┬──────┘                     │
│                                 │                             │
│                    ┌────────────┼────────────┐               │
│                    │            │            │               │
│             ┌──────▼─────┐ ┌───▼────────┐ ┌▼──────────┐    │
│             │   Node     │ │  Sample    │ │ Alert     │    │
│             │  Exporter  │ │    App     │ │ Manager   │    │
│             │ Port 9100  │ │ Port 8000  │ │ Port 9093 │    │
│             └────────────┘ └────────────┘ └───────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## クイックスタート

```bash
# 1. .env を作成し、Grafana 初期管理者を設定 (admin/admin で起動できないように env 必須化)
cp .env.example .env
# .env を編集: GF_SECURITY_ADMIN_USER / GF_SECURITY_ADMIN_PASSWORD を強いパスワードに

# 2. 起動
docker-compose up -d

# 3. 確認
docker-compose ps

# 4. ログ
docker-compose logs -f
```

## アクセス

| サービス | URL | 認証 |
|---------|-----|------|
| Grafana | http://localhost:3000 | .env で設定した `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` |
| Prometheus | http://localhost:9090 | - |
| AlertManager | http://localhost:9093 | - |
| Sample App | http://localhost:8000 | **本リポでは未同梱** (docker-compose.yml で sample-app をコメントアウト中)。実プロジェクトで `./app/Dockerfile` を追加してから有効化 |

## 監視メトリクス

### システムメトリクス（Node Exporter）
- CPU使用率
- メモリ使用率
- ディスク使用率
- ネットワークI/O

### アプリケーションメトリクス
- リクエスト数
- レスポンスタイム
- エラー率

## アラートルール

- インスタンスダウン
- CPU使用率 > 80%
- メモリ使用率 > 85%
- ディスク使用率 > 90%

## 停止

```bash
docker-compose down

# データも削除
docker-compose down -v
```

## 金融システム向け考慮事項

1. **SLI/SLO**: 可用性、レイテンシ、エラー率の定義
2. **アラート階層**: 重要度別の通知先設定
3. **監査ログ**: 変更履歴の保持
4. **冗長化**: Prometheus/Grafanaの冗長構成
