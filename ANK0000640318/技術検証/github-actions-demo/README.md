# GitHub Actions CI/CD Demo

金融決済プラットフォーム向けCI/CDパイプラインのデモです。

## パイプライン構成

```
Push/PR → Build → Security Scan → Deploy (Staging/Production)
```

## ワークフロー

### 1. Build & Test
- Dockerイメージのビルド
- キャッシュ活用による高速化

### 2. Security Scan
- Trivyによる脆弱性スキャン
- SARIF形式でのレポート出力
- GitHub Security tabへの連携

### 3. Deploy
- **Staging**: developブランチ → ステージング環境
- **Production**: mainブランチ → 本番環境
- 環境ごとの承認プロセス（environment protection rules）

## セキュリティ考慮

- シークレット管理: GitHub Secrets
- 脆弱性スキャン: Trivy
- 環境保護: approval required
- 監査ログ: GitHub Audit Log

## 使用方法

```bash
# ローカルでワークフローを確認
cat .github/workflows/ci-cd.yml

# actを使ったローカル実行（オプション）
act push
```

## 関連ファイル

- `.github/workflows/ci-cd.yml` - メインワークフロー (lint / test / build / scan / deploy ステージ)
- `Dockerfile` - コンテナイメージ定義 (multi-stage build + distroless)
- `../k8s-manifests/` - Kubernetes マニフェスト一式 (Deployment / Service / HPA / ConfigMap / Namespace)

## デモの範囲と限界

- 本デモは **CI/CD 構造の雛形** であり、本案件のクライアント環境固有の値 (WIF Provider, Service Account, manifest repo, ArgoCD endpoint, Prometheus URL) は GitHub Secrets で注入する想定です。
- `go.mod` / `go.sum` および `cmd/payment-api/` のコードは本デモには含めていません。実際の Go プロジェクトに移植する際に追加してください。
- 認証は **Workload Identity Federation (OIDC)** 前提で書いており、長期 SA 鍵 (`credentials_json` / `GCP_SA_KEY`) は使用しません。実運用ガイドは `../../参画用/運用ドキュメント/02_CI-CD運用ガイド.md` を参照。
