# CI/CD運用ガイド

## 1. 概要

### 1.1 目的
本ドキュメントは、CI/CDパイプラインの設計・運用ガイドラインを定義する。

### 1.2 CI/CDツール

| カテゴリ | ツール | 用途 |
|---------|--------|------|
| ソースコード管理 | GitHub | コードリポジトリ |
| CI/CD | GitHub Actions | ビルド・テスト・デプロイ |
| コンテナレジストリ | Artifact Registry | Dockerイメージ保存 |
| GitOps | ArgoCD | Kubernetes デプロイ |
| シークレット管理 | Secret Manager | 機密情報管理 |

---

## 2. パイプライン設計

### 2.1 全体フロー

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   開発者    │───>│   GitHub    │───>│GitHub Actions│
│ git push    │    │ Pull Request│    │   CI/CD     │
└─────────────┘    └─────────────┘    └──────┬──────┘
                                             │
       ┌─────────────────────────────────────┼─────────────────────────────────┐
       │                                     ▼                                 │
       │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
       │  │    Lint     │─>│    Test     │─>│   Build     │─>│Security Scan│  │
       │  │   (静的解析) │  │  (単体/結合) │  │ (Docker)    │  │  (Trivy)    │  │
       │  └─────────────┘  └─────────────┘  └─────────────┘  └──────┬──────┘  │
       │                                                            │         │
       │                                     ┌──────────────────────┘         │
       │                                     ▼                                 │
       │                          ┌─────────────────────┐                     │
       │                          │  Artifact Registry  │                     │
       │                          │   (イメージ保存)     │                     │
       │                          └──────────┬──────────┘                     │
       │                                     │                                 │
       │              ┌──────────────────────┼──────────────────────┐         │
       │              ▼                      ▼                      ▼         │
       │    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐  │
       │    │   Staging 環境  │   │   Production    │   │   Rollback      │  │
       │    │  (自動デプロイ)  │   │   (承認後)      │   │   (自動/手動)    │  │
       │    └─────────────────┘   └─────────────────┘   └─────────────────┘  │
       └───────────────────────────────────────────────────────────────────────┘
```

### 2.2 ブランチ戦略

| ブランチ | 用途 | デプロイ先 |
|---------|------|-----------|
| main | 本番リリース | Production |
| develop | 開発統合 | Staging |
| feature/* | 機能開発 | - |
| hotfix/* | 緊急修正 | Production |
| release/* | リリース準備 | Staging |

---

## 3. GitHub Actions 設定

### 3.1 CI ワークフロー

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [develop]

env:
  REGISTRY: asia-northeast1-docker.pkg.dev
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  IMAGE_NAME: payment-api

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Run golangci-lint
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest

  test:
    runs-on: ubuntu-latest
    needs: lint
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Run tests
        run: |
          go test -v -race -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.out

  build:
    runs-on: ubuntu-latest
    needs: test
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker asia-northeast1-docker.pkg.dev

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/payment/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security-scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.image-tag }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

### 3.2 CD ワークフロー（Staging）

```yaml
# .github/workflows/cd-staging.yml
name: CD Pipeline - Staging

on:
  push:
    branches: [develop]

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials payment-staging-gke \
            --region asia-northeast1

      - name: Update Kubernetes manifests
        run: |
          cd k8s/overlays/staging
          kustomize edit set image payment-api=${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/payment/payment-api:${{ github.sha }}

      - name: Deploy to Staging
        run: |
          kubectl apply -k k8s/overlays/staging

      - name: Wait for rollout
        run: |
          kubectl rollout status deployment/payment-api -n staging --timeout=300s

      - name: Run smoke tests
        run: |
          ./scripts/smoke-test.sh https://staging-api.example.com
```

### 3.3 CD ワークフロー（Production）

```yaml
# .github/workflows/cd-production.yml
name: CD Pipeline - Production

on:
  push:
    branches: [main]

jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials payment-prod-gke \
            --region asia-northeast1

      - name: Deploy with canary
        run: |
          # Canary deployment (10%)
          kubectl apply -k k8s/overlays/production-canary

          # Wait and monitor
          sleep 300

          # Check error rate
          ERROR_RATE=$(kubectl exec -n monitoring prometheus-0 -- \
            promql 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))')

          if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
            echo "Error rate too high, rolling back"
            kubectl rollout undo deployment/payment-api -n production
            exit 1
          fi

          # Full rollout
          kubectl apply -k k8s/overlays/production

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "Production deployment completed: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 4. ArgoCD GitOps 設定

### 4.1 Application定義

```yaml
# argocd/applications/payment-api.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payment-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/payment-platform
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 4.2 Sync戦略

| 戦略 | 用途 | 設定 |
|------|------|------|
| 自動Sync | Staging | automated: true |
| 手動Sync | Production | automated: false |
| セルフヒール | 全環境 | selfHeal: true |
| Prune | 全環境 | prune: true |

---

## 5. ロールバック手順

### 5.1 自動ロールバック条件

| 条件 | 閾値 | アクション |
|------|------|----------|
| エラー率 | > 1% | 自動ロールバック |
| レイテンシ | P99 > 500ms | アラート |
| Pod再起動 | > 3回/5分 | 自動ロールバック |

### 5.2 手動ロールバック手順

```bash
# 1. 現在のリビジョン確認
kubectl rollout history deployment/payment-api -n production

# 2. 前のリビジョンにロールバック
kubectl rollout undo deployment/payment-api -n production

# 3. 特定リビジョンにロールバック
kubectl rollout undo deployment/payment-api -n production --to-revision=3

# 4. ロールバック状況確認
kubectl rollout status deployment/payment-api -n production
```

### 5.3 ArgoCD経由でのロールバック

```bash
# 1. 履歴確認
argocd app history payment-api

# 2. 特定リビジョンに戻す
argocd app rollback payment-api <REVISION>

# 3. Sync
argocd app sync payment-api
```

---

## 6. シークレット管理

### 6.1 Secret Manager連携

```yaml
# external-secrets/payment-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: payment-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-store
    kind: ClusterSecretStore
  target:
    name: payment-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: payment-database-url
    - secretKey: api-key
      remoteRef:
        key: payment-api-key
```

### 6.2 シークレットローテーション

| シークレット | ローテーション頻度 | 方法 |
|-------------|------------------|------|
| DBパスワード | 90日 | Secret Manager + External Secrets |
| APIキー | 30日 | Secret Manager + 自動更新 |
| TLS証明書 | 自動 | cert-manager |

---

## 7. 監視・アラート

### 7.1 パイプライン監視

| メトリクス | 閾値 | アラート |
|-----------|------|---------|
| ビルド時間 | > 10分 | Warning |
| テストカバレッジ | < 80% | Block |
| セキュリティ脆弱性 | Critical | Block |
| デプロイ時間 | > 5分 | Warning |

### 7.2 デプロイ通知

```yaml
# Slack通知設定
notifications:
  - trigger: on-sync-succeeded
    channel: "#deployments"
    template: |
      Application {{ .app.metadata.name }} synced successfully.
      Revision: {{ .app.status.sync.revision }}

  - trigger: on-sync-failed
    channel: "#alerts"
    template: |
      Application {{ .app.metadata.name }} sync failed!
      Error: {{ .app.status.conditions }}
```

---

## 8. ベストプラクティス

### 8.1 コミットルール

```
<type>(<scope>): <subject>

<body>

<footer>

Types: feat, fix, docs, style, refactor, test, chore
Example: feat(api): add payment validation endpoint
```

### 8.2 PRルール

- [ ] テストが全て通過
- [ ] コードレビュー承認（2名以上）
- [ ] セキュリティスキャン通過
- [ ] ドキュメント更新

### 8.3 デプロイルール

| 環境 | 条件 |
|------|------|
| Development | PR作成時自動 |
| Staging | develop マージ時自動 |
| Production | main マージ + 承認 |

---

## 9. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
