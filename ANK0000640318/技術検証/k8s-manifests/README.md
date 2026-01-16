# Kubernetes Manifests

金融決済プラットフォーム向けKubernetesマニフェスト集です。

## ディレクトリ構成

```
k8s-manifests/
├── README.md
├── namespace.yaml          # Namespace定義
├── deployment.yaml         # Deployment定義
├── service.yaml           # Service定義
├── ingress.yaml           # Ingress定義
├── configmap.yaml         # ConfigMap定義
├── secret.yaml            # Secret定義（テンプレート）
├── hpa.yaml               # Horizontal Pod Autoscaler
└── network-policy.yaml    # NetworkPolicy
```

## 使用方法

### 1. Namespaceの作成

```bash
kubectl apply -f namespace.yaml
```

### 2. リソースのデプロイ

```bash
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
kubectl apply -f network-policy.yaml
```

### 3. 確認

```bash
kubectl get all -n payment-platform
kubectl get ingress -n payment-platform
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
