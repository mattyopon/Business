# データ処理パイプライン デモ (構想メモ)

> **本ディレクトリは構想メモのみで、コード一式は同梱していません。** 案件に合わせて雛形を流用する際は、本ファイル末尾の「実装する場合のスケルトン」をベースに段階的に整備してください。
> リポジトリのテンプレートとしては「読み手が即流用できるレベルの最小限の実体」だけを置き、肥大化したREADMEと実体ゼロのギャップは避けるのが本リポの方針です。

## 想定するパイプライン

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Extract   │────>│  Transform  │────>│    Load     │
│  (データ取得) │     │  (データ変換) │     │ (データ投入) │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      v                   v                   v
  S3/API              Kubernetes          Database
  Source                Jobs              Target
```

- オーケストレーション: GitHub Actions (cron schedule + workflow_dispatch)
- 実行基盤: Kubernetes Jobs (Argo Workflows は DAG が複雑になってきた段階で導入検討)
- シークレット管理: External Secrets Operator → AWS Secrets Manager / GCP Secret Manager
- 観測性: Job 完了時に Prometheus Pushgateway / Cloud Logging へ結果出力

## 実装する場合のスケルトン (推奨手順)

1. `app/` または `src/{extract,transform,load}/` にロジック (Python / Go) を実装
2. `docker/Dockerfile` を作成し、Multi-stage build + distroless でイメージサイズと攻撃面を抑制
3. `.github/workflows/daily-etl.yml` を作成 (cron schedule + Workload Identity Federation / GitHub OIDC)
4. `kubernetes/jobs/{extract,transform,load}-job.yaml` を作成。**`ttlSecondsAfterFinished`** と **`backoffLimit`** を必ず設定
5. `kubernetes/configmap.yaml` / `secret.yaml` (External Secrets 連携) を整備
6. CI/CD 経由でない再実行を可能にするため、すべてのJobは冪等性 (idempotent) を保つ実装にする

## やってはいけないこと

- 長期 AWS / GCP 鍵を GitHub Secrets に保存して `kubectl apply` する: **OIDC / Workload Identity Federation を使う**
- `restartPolicy: OnFailure` で無制限リトライ: **`backoffLimit` 必須**
- Job 完了後の手動削除運用: **`ttlSecondsAfterFinished` で自動削除**
- 設計時の `placeholder` 値を本番リソースのまま運用: **本リポの参画用ドキュメント (06系) の連絡網雛形ノートと同じ精神で、実値で必ず置き換える**

## 参考資料

- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [GitHub Actions cron](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)
- [Argo Workflows](https://argoproj.github.io/argo-workflows/)
- [External Secrets Operator](https://external-secrets.io/)
