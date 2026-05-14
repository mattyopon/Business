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

      - name: Authenticate to Google Cloud (Workload Identity Federation / OIDC)
        uses: google-github-actions/auth@v2
        with:
          # 長期 SA 鍵 (credentials_json) は使用しない。WIF 経由で短命 OIDC トークンを利用する。
          # WIF Pool / Provider / SA は事前に Terraform で構築済み (terraform/workload_identity.tf)
          workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_DEPLOY_SA }}

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

### 3.2 CD ワークフロー（Staging / GitOps）

> **GitOps 一本化**: 本案件は ArgoCD を宣言元として運用する。GitHub Actions は **マニフェスト Repo の tag を書き換えて commit / push するのみ**。実際の `kubectl apply` は ArgoCD が sync で行う。
> `kubectl apply -k` を CI から直接打たないことで、宣言元の二重化とドリフトを避ける。

```yaml
# .github/workflows/cd-staging.yml
name: CD Pipeline - Staging

on:
  push:
    branches: [develop]

env:
  REGISTRY: asia-northeast1-docker.pkg.dev
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}  # GitHub Environment 'staging' の variables/secrets でも可
  IMAGE_NAME: payment-api
  MANIFEST_REPO: payment/payment-manifests   # ArgoCD が監視する別リポジトリ
  ARGOCD_APP: payment-staging

permissions:
  id-token: write   # WIF 用に必須
  contents: read

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_DEPLOY_SA }}

      - name: Checkout manifest repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.MANIFEST_REPO }}
          token: ${{ secrets.GH_PAT_MANIFEST }}
          path: manifests

      - name: Bump image tag in manifest repo
        working-directory: manifests/overlays/staging
        run: |
          kustomize edit set image \
            payment-api=${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/payment/${{ env.IMAGE_NAME }}:${{ github.sha }}
          git config user.email "ci-bot@example.com"
          git config user.name "ci-bot"
          git add kustomization.yaml
          git commit -m "chore(staging): bump payment-api to ${{ github.sha }}"
          git push

      - name: Trigger ArgoCD sync and wait for healthy
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
        run: |
          argocd app sync "${ARGOCD_APP}" --prune --timeout 300
          argocd app wait "${ARGOCD_APP}" --health --operation --timeout 300

      - name: Run smoke tests
        run: |
          ./scripts/smoke-test.sh https://staging-api.example.com
```

### 3.3 CD ワークフロー（Production / Canary + GitOps）

> Production も GitOps を継承し、`canary` → `wait & verify` → `full` の 3段階を **manifest repo の overlays 切替** で行う。
> エラー率判定は Prometheus HTTP API (`/api/v1/query`) を curl で叩く。`promql` というCLIは標準で存在せず、`kubectl exec` での実行は依存しすぎるため避ける。

```yaml
# .github/workflows/cd-production.yml
name: CD Pipeline - Production

on:
  push:
    branches: [main]

env:
  REGISTRY: asia-northeast1-docker.pkg.dev
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  IMAGE_NAME: payment-api
  MANIFEST_REPO: payment/payment-manifests
  ARGOCD_APP_CANARY: payment-prod-canary
  ARGOCD_APP_PROD: payment-prod
  PROMETHEUS_URL: ${{ secrets.PROMETHEUS_URL }}  # 例: https://prometheus.internal.example.com

permissions:
  id-token: write
  contents: read

jobs:
  deploy-production:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_DEPLOY_SA }}

      - name: Checkout manifest repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.MANIFEST_REPO }}
          token: ${{ secrets.GH_PAT_MANIFEST }}
          path: manifests

      - name: Bump canary tag
        working-directory: manifests/overlays/production-canary
        run: |
          kustomize edit set image \
            payment-api=${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/payment/${{ env.IMAGE_NAME }}:${{ github.sha }}
          git config user.email "ci-bot@example.com"
          git config user.name "ci-bot"
          git add kustomization.yaml
          git commit -m "chore(prod-canary): bump payment-api to ${{ github.sha }}"
          git push

      - name: ArgoCD sync canary and wait healthy
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
        run: |
          argocd app sync "${ARGOCD_APP_CANARY}" --prune --timeout 300
          argocd app wait "${ARGOCD_APP_CANARY}" --health --operation --timeout 300

      - name: Observe canary error rate (5min)
        env:
          PROM_TOKEN: ${{ secrets.PROMETHEUS_BEARER_TOKEN }}
        run: |
          sleep 300
          QUERY='sum(rate(http_requests_total{app="payment-api",track="canary",status=~"5.."}[5m])) / sum(rate(http_requests_total{app="payment-api",track="canary"}[5m]))'
          RESP=$(curl -sf -G \
            -H "Authorization: Bearer ${PROM_TOKEN}" \
            --data-urlencode "query=${QUERY}" \
            "${PROMETHEUS_URL}/api/v1/query")
          ERROR_RATE=$(echo "${RESP}" | jq -r '.data.result[0].value[1] // "0"')
          echo "canary 5xx ratio = ${ERROR_RATE}"
          awk -v r="${ERROR_RATE}" 'BEGIN { if (r+0 > 0.01) exit 1 }'

      - name: Bump production tag (full rollout)
        working-directory: manifests/overlays/production
        run: |
          kustomize edit set image \
            payment-api=${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/payment/${{ env.IMAGE_NAME }}:${{ github.sha }}
          git add kustomization.yaml
          git commit -m "chore(prod): promote payment-api ${{ github.sha }} after canary"
          git push

      - name: ArgoCD sync production
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
        run: |
          argocd app sync "${ARGOCD_APP_PROD}" --prune --timeout 600
          argocd app wait "${ARGOCD_APP_PROD}" --health --operation --timeout 600

      - name: Rollback on failure
        if: failure()
        env:
          ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
          ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}
        run: |
          # 直前の synced revision に戻す (manifest repo の git revert で実施)
          git -C manifests revert --no-edit HEAD
          git -C manifests push
          argocd app sync "${ARGOCD_APP_CANARY}" --revision HEAD~1 --timeout 300 || true

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
