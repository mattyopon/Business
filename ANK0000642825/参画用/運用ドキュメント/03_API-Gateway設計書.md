# 03. API Gateway + Cognito 設計書

## 1. 目的

検索システムの公開エンドポイントを Amazon API Gateway (REST) で提供し、Amazon Cognito User Pool を IdP として認証 / 認可を行う構成を定義する。

## 2. 構成概要

```
Client (Web/Mobile)
   │
   ├─ Sign-in → Cognito User Pool (Hosted UI)
   │     └─ ID Token / Access Token (JWT)
   │
   └─ HTTPS + Authorization: Bearer <token>
         ↓
      CloudFront (任意)
         ↓
      API Gateway (REST, REGIONAL)
         ├─ Cognito Authorizer (JWT verify)
         ├─ Request Validator (params/body)
         ├─ Usage Plan / API Key (任意, 内部系のみ)
         └─ Lambda Integration (Proxy)
              ↓
           Lambda (Search / Index)
              ↓ (VPC内)
           OpenSearch Service
```

## 3. API 設計

### 3.1 リソース構成

| パス | メソッド | 認証 | 概要 |
|------|---------|------|------|
| `/v1/search` | GET | Cognito | キーワード検索 (q, page, size) |
| `/v1/search/suggest` | GET | Cognito | 補完検索 (prefix) |
| `/v1/indices/{name}/_doc` | POST | Cognito (admin scope) | ドキュメント投入 |
| `/v1/indices/{name}/_doc/{id}` | DELETE | Cognito (admin scope) | ドキュメント削除 |
| `/_healthcheck` | GET | None | 死活確認 (Route 53 / 外形監視用) |

### 3.2 共通仕様

- HTTPS 必須 (TLS 1.2 以上)
- Authorization ヘッダに ID Token (JWT) を `Bearer <token>` で付与
- `Content-Type: application/json; charset=utf-8`
- レスポンスは `application/json`。タイムスタンプは ISO 8601 (UTC)
- リクエスト ID: API Gateway で `$context.requestId` を付与し、レスポンスヘッダ `X-Request-Id` で返却

### 3.3 エラーレスポンス

```json
{
  "error": {
    "code": "INVALID_QUERY",
    "message": "Query parameter 'q' is required",
    "requestId": "abcd-1234"
  }
}
```

主なステータス: 400 (validation) / 401 (auth missing) / 403 (auth invalid) / 404 / 429 (throttle) / 500 / 503 (upstream)

## 4. Cognito 設計

### 4.1 User Pool

| 項目 | 設定値 |
|------|--------|
| ユーザー名 | email |
| パスワードポリシー | 最低 12文字、英大小数記号必須 |
| MFA | OPTIONAL (Software TOTP) — 管理者ロールは REQUIRED 推奨 |
| アカウント復旧 | verified_email のみ |
| 属性 | email (required, verified), name |

### 4.2 App Client

| 項目 | 設定値 |
|------|--------|
| Client Secret | 無効 (SPA / モバイル前提) |
| 認証フロー | `ALLOW_USER_SRP_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH` |
| トークン有効期限 | Access/ID: 1h / Refresh: 30d |
| 許可スコープ | `openid`, `email`, `profile`, `search/read`, `search/admin` |

### 4.3 グループ

| グループ | スコープ | 用途 |
|---------|---------|------|
| `search-users` | `search/read` | 通常検索ユーザー |
| `search-admins` | `search/read`, `search/admin` | 投入/削除 |

## 5. API Gateway 設定

### 5.1 認可

- 認可方式: `COGNITO_USER_POOLS`
- 検証: トークンの `aud` が App Client ID と一致、`token_use=id`
- スコープ別エンドポイントで `OAuth Scopes` を強制

### 5.2 スロットリング

| 階層 | RPS | Burst |
|------|-----|-------|
| アカウント全体 | 10000 | 5000 |
| `/v1/search` ステージ | 200 | 400 |
| `/v1/indices/*` ステージ | 20 | 40 |

### 5.3 ロギング

- Access Logs: CloudWatch Logs (`/aws/apigateway/<api-id>/access`)
- Execution Logs: ERROR level (本番), INFO level (dev/stg)
- X-Ray Tracing: 有効 (sampling 10% / errors 100%)

## 6. CORS

| 項目 | 値 |
|------|----|
| Allowed Origins | フロントSPAドメインのみ (ワイルドカード禁止) |
| Allowed Methods | GET, POST, DELETE, OPTIONS |
| Allowed Headers | `Authorization`, `Content-Type`, `X-Requested-With` |
| Max Age | 600s |

## 7. セキュリティ

- AWS WAF を CloudFront または API Gateway に関連付け (SQLi / XSS / Rate-based / Bot Control)
- API Key は内部システム連携のみで使用 (顧客向け公開エンドポイントには付与しない)
- VPC Endpoint (`execute-api`) でプライベートAPI化する場合は別ステージで `PRIVATE` 構成
- CloudTrail Data Events で API Gateway / Cognito の管理操作を記録

## 8. 障害時のフェイルセーフ

- Cognito 障害時: 既存 Access Token は失効しないため、新規ログイン不能だが既ログインユーザーは継続利用可
- OpenSearch 障害時: API Gateway が 503 を返却。`Retry-After` ヘッダで指数バックオフを推奨

## 9. 関連資料

- [01_AWSインフラ設計書.md](01_AWSインフラ設計書.md)
- [02_OpenSearch運用ガイド.md](02_OpenSearch運用ガイド.md)
- [04_監視設計書.md](04_監視設計書.md)
- [05_セキュリティガイドライン.md](05_セキュリティガイドライン.md)
- [06_障害対応Runbook.md](06_障害対応Runbook.md)
