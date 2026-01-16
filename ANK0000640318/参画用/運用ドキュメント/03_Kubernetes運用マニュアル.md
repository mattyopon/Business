# Kubernetes運用マニュアル

## 1. 概要

### 1.1 目的
本ドキュメントは、GKE/EKSクラスターの運用手順を定義する。

### 1.2 対象クラスター

| 環境 | プラットフォーム | クラスター名 |
|------|----------------|-------------|
| Production | GKE Autopilot | payment-prod-gke |
| Staging | GKE Autopilot | payment-staging-gke |
| DR | EKS | payment-dr-eks |

---

## 2. クラスター接続

### 2.1 GKE接続

```bash
# 認証（初回のみ）
gcloud auth login
gcloud config set project <PROJECT_ID>

# クラスター認証情報取得
gcloud container clusters get-credentials payment-prod-gke \
  --region asia-northeast1

# 接続確認
kubectl cluster-info
kubectl get nodes
```

### 2.2 EKS接続

```bash
# AWS認証（初回のみ）
aws configure

# クラスター認証情報取得
aws eks update-kubeconfig \
  --region ap-northeast-1 \
  --name payment-dr-eks

# 接続確認
kubectl cluster-info
```

### 2.3 コンテキスト切り替え

```bash
# コンテキスト一覧
kubectl config get-contexts

# コンテキスト切り替え
kubectl config use-context gke_<project>_asia-northeast1_payment-prod-gke

# 現在のコンテキスト確認
kubectl config current-context
```

---

## 3. 基本オペレーション

### 3.1 リソース確認

```bash
# Pod一覧
kubectl get pods -n production

# Pod詳細
kubectl describe pod <pod-name> -n production

# ログ確認
kubectl logs <pod-name> -n production
kubectl logs <pod-name> -n production --previous  # 前回のログ
kubectl logs -f <pod-name> -n production          # フォロー

# リソース使用状況
kubectl top pods -n production
kubectl top nodes
```

### 3.2 デプロイメント操作

```bash
# デプロイメント一覧
kubectl get deployments -n production

# スケール変更
kubectl scale deployment payment-api --replicas=5 -n production

# イメージ更新
kubectl set image deployment/payment-api \
  payment-api=asia-northeast1-docker.pkg.dev/project/repo/payment-api:v1.2.0 \
  -n production

# ロールアウト状況
kubectl rollout status deployment/payment-api -n production

# ロールアウト履歴
kubectl rollout history deployment/payment-api -n production

# ロールバック
kubectl rollout undo deployment/payment-api -n production
```

### 3.3 サービス確認

```bash
# サービス一覧
kubectl get services -n production

# エンドポイント確認
kubectl get endpoints -n production

# Ingress確認
kubectl get ingress -n production
kubectl describe ingress payment-ingress -n production
```

---

## 4. トラブルシューティング

### 4.1 Pod起動失敗

```bash
# Pod状態確認
kubectl get pods -n production
kubectl describe pod <pod-name> -n production

# イベント確認
kubectl get events -n production --sort-by='.lastTimestamp'

# よくある原因と対処
# - ImagePullBackOff: イメージ名確認、レジストリ認証確認
# - CrashLoopBackOff: ログ確認、コンテナ起動コマンド確認
# - Pending: リソース不足、ノード確認
# - OOMKilled: メモリ制限増加
```

### 4.2 デバッグ用Pod起動

```bash
# 一時的なデバッグPod
kubectl run debug --rm -it --image=busybox -n production -- /bin/sh

# 特定Podと同じネットワークでデバッグ
kubectl debug <pod-name> -it --image=busybox -n production

# DNS確認
kubectl run dns-test --rm -it --image=busybox -n production -- nslookup payment-api

# DB接続確認
kubectl run pg-test --rm -it --image=postgres:15 -n production -- \
  psql -h <db-host> -U <user> -d <database>
```

### 4.3 ネットワーク診断

```bash
# Service DNS確認
kubectl exec -it <pod-name> -n production -- nslookup payment-api.production.svc.cluster.local

# 接続確認
kubectl exec -it <pod-name> -n production -- curl -v http://payment-api:8080/health

# NetworkPolicy確認
kubectl get networkpolicies -n production
kubectl describe networkpolicy <policy-name> -n production
```

---

## 5. HPA（水平Pod自動スケーリング）

### 5.1 HPA設定確認

```bash
# HPA一覧
kubectl get hpa -n production

# HPA詳細
kubectl describe hpa payment-api-hpa -n production
```

### 5.2 HPA設定例

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: payment-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payment-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

---

## 6. ConfigMap・Secret管理

### 6.1 ConfigMap操作

```bash
# ConfigMap一覧
kubectl get configmaps -n production

# ConfigMap作成
kubectl create configmap app-config \
  --from-file=config.yaml \
  -n production

# ConfigMap更新
kubectl apply -f configmap.yaml

# ConfigMap確認
kubectl describe configmap app-config -n production
```

### 6.2 Secret操作

```bash
# Secret一覧
kubectl get secrets -n production

# Secret作成（リテラル値）
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n production

# Secret確認（Base64デコード）
kubectl get secret db-secret -n production -o jsonpath='{.data.password}' | base64 -d

# Secret更新（External Secrets使用推奨）
kubectl apply -f external-secret.yaml
```

---

## 7. メンテナンス作業

### 7.1 ノードメンテナンス

```bash
# ノードをスケジュール不可に
kubectl cordon <node-name>

# ノード上のPodを退避
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# メンテナンス完了後、スケジュール可能に
kubectl uncordon <node-name>
```

### 7.2 クラスターアップグレード

```bash
# GKE - 利用可能なバージョン確認
gcloud container get-server-config --region asia-northeast1

# GKE - コントロールプレーンアップグレード
gcloud container clusters upgrade payment-prod-gke \
  --region asia-northeast1 \
  --master

# GKE - ノードプールアップグレード（Autopilotの場合は自動）
gcloud container clusters upgrade payment-prod-gke \
  --region asia-northeast1 \
  --node-pool default-pool
```

### 7.3 リソースクリーンアップ

```bash
# 完了/失敗したJobの削除
kubectl delete jobs --field-selector status.successful=1 -n production
kubectl delete jobs --field-selector status.failed=1 -n production

# 古いReplicaSetの削除
kubectl delete rs $(kubectl get rs -n production -o jsonpath='{.items[?(@.spec.replicas==0)].metadata.name}') -n production

# Evicted Podの削除
kubectl delete pods --field-selector=status.phase=Failed -n production
```

---

## 8. 監視・ログ

### 8.1 Pod監視

```bash
# リソース使用状況（リアルタイム）
watch kubectl top pods -n production

# Pod状態監視
kubectl get pods -n production -w

# 全Namespace概要
kubectl get pods --all-namespaces
```

### 8.2 ログ収集

```bash
# 複数Podのログ（stern使用）
stern payment-api -n production

# ログをファイルに保存
kubectl logs <pod-name> -n production > /tmp/pod-log.txt

# 全コンテナのログ
kubectl logs <pod-name> --all-containers -n production
```

### 8.3 メトリクス確認

```bash
# Prometheus経由でメトリクス確認
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# Grafana接続
kubectl port-forward svc/grafana 3000:3000 -n monitoring
```

---

## 9. セキュリティ

### 9.1 RBAC確認

```bash
# Role一覧
kubectl get roles -n production
kubectl get clusterroles

# RoleBinding確認
kubectl get rolebindings -n production
kubectl describe rolebinding <name> -n production

# 権限テスト
kubectl auth can-i get pods -n production --as system:serviceaccount:production:payment-api
```

### 9.2 NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payment-api-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: istio-system
        - podSelector:
            matchLabels:
              app: istio-ingressgateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: production
      ports:
        - protocol: TCP
          port: 5432  # PostgreSQL
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53   # DNS
```

### 9.3 Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## 10. 緊急対応手順

### 10.1 サービス停止時

```bash
# 1. 状況確認
kubectl get pods -n production
kubectl get events -n production --sort-by='.lastTimestamp'

# 2. 問題Podの特定
kubectl describe pod <problem-pod> -n production

# 3. ログ確認
kubectl logs <problem-pod> -n production --previous

# 4. 即時対応（必要に応じて）
kubectl rollout undo deployment/payment-api -n production
# または
kubectl scale deployment payment-api --replicas=5 -n production
```

### 10.2 リソース枯渇時

```bash
# 1. リソース状況確認
kubectl top nodes
kubectl top pods -n production

# 2. 不要Podの削除
kubectl delete pod <pod-name> -n production

# 3. スケールダウン（必要に応じて）
kubectl scale deployment <name> --replicas=1 -n production

# 4. GKE Autopilotの場合は自動調整を待つ
```

---

## 11. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
