# Kubernetes Manifests

金融決済プラットフォーム向けKubernetesマニフェスト集です。

## ディレクトリ構成 (本リポ同梱分)

```
k8s-manifests/
├── README.md
├── namespace.yaml          # Namespace定義 (payment-platform)
├── deployment.yaml         # Deployment定義
├── service.yaml           # Service定義
├── configmap.yaml         # ConfigMap + Secret 雛形 (payment-platform namespace)
└── hpa.yaml               # Horizontal Pod Autoscaler
```

> **同梱しない / 案件側で追加するもの** (本デモは構造検証が目的のため意図的に省略):
> - `ingress.yaml` — クライアントの Ingress Controller (例: GKE Ingress, NGINX, Contour) に応じて作成
> - `network-policy.yaml` — クライアントのネットワーク要件 (Calico / Cilium ポリシー) に応じて作成
> - `secret.yaml` を Git 管理する代わりに **External Secrets Operator** で AWS Secrets Manager / GCP Secret Manager から注入する運用を推奨

## 使用方法

### 1. Namespace 作成

```bash
kubectl apply -f namespace.yaml   # payment-platform を作成
```

### 2. リソースのデプロイ

```bash
kubectl apply -f configmap.yaml   # ConfigMap + Secret 雛形 (payment-platform namespace)
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml
# ingress / network-policy は案件側で追加 (前述)
```

### 3. 確認

```bash
kubectl get all -n payment-platform
# Ingress を別途追加した場合のみ
# kubectl get ingress -n payment-platform
```

## セキュリティ考慮

- **NetworkPolicy**: Pod間通信の制限
- **SecurityContext**: 非rootユーザーでの実行
- **ResourceQuota**: リソース制限
- **Secret管理**: External Secrets Operator連携（推奨）

## 本番環境向け推奨事項

1. **シークレット管理**: Vault, External Secrets Operatorの使用
2. **GitOps**: ArgoCD/Fluxによる自動同期
3. **監視**: Prometheus/Grafanaとの連携
4. **ログ**: Fluent Bit/Fluentdによるログ収集
