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

- `.github/workflows/ci-cd.yml` - メインワークフロー
- `Dockerfile` - コンテナイメージ定義（追加予定）
- `k8s/` - Kubernetesマニフェスト（追加予定）
