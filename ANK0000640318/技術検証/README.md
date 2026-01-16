# 技術検証 - 金融決済プラットフォーム基盤運用案件

## 概要

金融決済プラットフォーム基盤運用案件向けの技術デモプロジェクトです。
SRE、CI/CD、コンテナ技術、監視の実践的なスキルを示します。

---

## デモプロジェクト一覧

| プロジェクト | 説明 | 技術スタック |
|-------------|------|-------------|
| [github-actions-demo](./github-actions-demo/) | CI/CDパイプラインのデモ | GitHub Actions, Docker, Kubernetes |
| [k8s-manifests](./k8s-manifests/) | Kubernetesマニフェスト集 | Kubernetes, Helm |
| [monitoring-demo](./monitoring-demo/) | 監視・オブザーバビリティのデモ | Prometheus, Grafana, AlertManager |
| [terraform-gcp](./terraform-gcp/) | GCPインフラのIaC | Terraform, GCP |

---

## クイックスタート

### 1. 監視デモ

```bash
cd monitoring-demo
docker-compose up -d
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

### 2. CI/CDデモ

GitHub Actionsのワークフロー例を確認：
```bash
cd github-actions-demo
cat .github/workflows/ci-cd.yml
```

### 3. Kubernetesマニフェスト

```bash
cd k8s-manifests
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

---

## 技術マップ

| 案件要件 | 対応デモ |
|---------|---------|
| CI/CDパイプライン構築 | github-actions-demo |
| コンテナ技術（Docker, Kubernetes） | k8s-manifests, github-actions-demo |
| クラウドインフラ（GCP/AWS） | terraform-gcp |
| SRE領域の改善 | monitoring-demo |

---

## 関連リンク

- [商談準備資料](../商談用/商談準備資料.md)
- [技術用語解説](../商談用/技術用語解説.md)
- [想定Q&A](../商談用/想定Q&A.md)
