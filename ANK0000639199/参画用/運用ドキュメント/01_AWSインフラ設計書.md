# AWSインフラ設計書

## 1. 概要

### 1.1 目的
本ドキュメントは、医療AIプラットフォームのAWSインフラ設計を定義する。

### 1.2 対象システム
- **システム名**: [プロダクト名]
- **環境**: Production / Staging / Development
- **リージョン**: ap-northeast-1（東京）

### 1.3 設計原則
- AWS Well-Architected Framework に準拠
- 高可用性（99.9%以上）
- セキュリティファースト（医療データ保護）
- コスト最適化

---

## 2. アーキテクチャ概要

### 2.1 システム構成図

```
                              ┌─────────────────────────────────────┐
                              │            AWS Cloud                 │
┌──────────┐                  │  ┌─────────────────────────────┐    │
│  Users   │──── Internet ────│──│      CloudFront + WAF       │    │
└──────────┘                  │  └──────────────┬──────────────┘    │
                              │                 │                    │
                              │  ┌──────────────▼──────────────┐    │
                              │  │     Application Load         │    │
                              │  │        Balancer              │    │
                              │  └──────────────┬──────────────┘    │
                              │                 │                    │
                              │  ┌──────────────▼──────────────┐    │
                              │  │     EKS Cluster (Fargate)   │    │
                              │  │  ┌─────┐ ┌─────┐ ┌─────┐    │    │
                              │  │  │ API │ │ ML  │ │Worker│   │    │
                              │  │  │ Pod │ │ Pod │ │ Pod │    │    │
                              │  │  └─────┘ └─────┘ └─────┘    │    │
                              │  └──────────────┬──────────────┘    │
                              │                 │                    │
                              │  ┌──────────────▼──────────────┐    │
                              │  │     Aurora MySQL (Multi-AZ) │    │
                              │  └─────────────────────────────┘    │
                              │                                      │
                              │  ┌─────────────┐ ┌─────────────┐    │
                              │  │     S3      │ │    ECR      │    │
                              │  │  (Models)   │ │  (Images)   │    │
                              │  └─────────────┘ └─────────────┘    │
                              └─────────────────────────────────────┘
```

### 2.2 環境構成

| 環境 | 用途 | VPC CIDR |
|------|------|----------|
| Production | 本番環境 | 10.0.0.0/16 |
| Staging | 検証環境 | 10.1.0.0/16 |
| Development | 開発環境 | 10.2.0.0/16 |

---

## 3. ネットワーク設計

### 3.1 VPC設計

| 項目 | 設定値 |
|------|--------|
| VPC CIDR | 10.0.0.0/16 |
| DNS Hostnames | Enabled |
| DNS Resolution | Enabled |

### 3.2 サブネット設計

| サブネット | CIDR | AZ | 用途 |
|-----------|------|-----|------|
| public-1a | 10.0.1.0/24 | ap-northeast-1a | ALB, NAT Gateway |
| public-1c | 10.0.2.0/24 | ap-northeast-1c | ALB, NAT Gateway |
| public-1d | 10.0.3.0/24 | ap-northeast-1d | ALB, NAT Gateway |
| private-1a | 10.0.11.0/24 | ap-northeast-1a | EKS, RDS |
| private-1c | 10.0.12.0/24 | ap-northeast-1c | EKS, RDS |
| private-1d | 10.0.13.0/24 | ap-northeast-1d | EKS, RDS |

### 3.3 セキュリティグループ設計

#### ALB Security Group
| Type | Protocol | Port | Source | 説明 |
|------|----------|------|--------|------|
| Inbound | HTTPS | 443 | 0.0.0.0/0 | HTTPS通信 |
| Outbound | All | All | 0.0.0.0/0 | 全許可 |

#### EKS Security Group
| Type | Protocol | Port | Source | 説明 |
|------|----------|------|--------|------|
| Inbound | TCP | 443 | ALB-SG | API通信 |
| Inbound | TCP | 10250 | EKS-SG | Kubelet |
| Outbound | All | All | 0.0.0.0/0 | 全許可 |

#### RDS Security Group
| Type | Protocol | Port | Source | 説明 |
|------|----------|------|--------|------|
| Inbound | TCP | 3306 | EKS-SG | MySQL接続 |
| Outbound | All | All | 0.0.0.0/0 | 全許可 |

---

## 4. コンピューティング設計

### 4.1 EKS クラスター

| 項目 | 設定値 |
|------|--------|
| Kubernetes Version | 1.28 |
| クラスター名 | medical-ai-prod-eks |
| エンドポイントアクセス | Private + Public |
| ログタイプ | api, audit, authenticator |

### 4.2 Fargate プロファイル

| プロファイル | Namespace | 用途 |
|-------------|-----------|------|
| default | default, kube-system | システムPod |
| application | app | アプリケーションPod |
| mlops | mlops | ML推論Pod |

### 4.3 リソース要件

| ワークロード | CPU Request | Memory Request | Replicas |
|-------------|-------------|----------------|----------|
| API Server | 500m | 1Gi | 3 |
| ML Inference | 2000m | 4Gi | 2 |
| Worker | 1000m | 2Gi | 3 |

---

## 5. データベース設計

### 5.1 Aurora MySQL

| 項目 | 設定値 |
|------|--------|
| エンジン | Aurora MySQL 8.0 |
| インスタンスクラス | db.r6g.large |
| マルチAZ | Enabled |
| ストレージ暗号化 | Enabled (KMS) |
| バックアップ保持期間 | 35日 |
| メンテナンスウィンドウ | 日曜 04:00-05:00 JST |

### 5.2 パラメータグループ

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| character_set_server | utf8mb4 | 文字セット |
| time_zone | Asia/Tokyo | タイムゾーン |
| max_connections | 1000 | 最大接続数 |
| slow_query_log | 1 | スロークエリログ |
| long_query_time | 1 | スロークエリ閾値(秒) |

---

## 6. ストレージ設計

### 6.1 S3 バケット

| バケット名 | 用途 | 暗号化 | バージョニング |
|-----------|------|--------|---------------|
| medical-ai-prod-models | MLモデル保存 | SSE-KMS | Enabled |
| medical-ai-prod-data | データ保存 | SSE-KMS | Enabled |
| medical-ai-prod-logs | ログ保存 | SSE-S3 | Disabled |

### 6.2 ライフサイクルポリシー

| バケット | ルール |
|---------|--------|
| models | 古いバージョンは90日後に削除 |
| data | 365日後にGlacierへ移行 |
| logs | 90日後に削除 |

---

## 7. CDN・WAF設計

### 7.1 CloudFront

| 項目 | 設定値 |
|------|--------|
| オリジン | ALB |
| SSL証明書 | ACM (*.example.com) |
| キャッシュポリシー | Managed-CachingOptimized |
| 価格クラス | PriceClass_200 |

### 7.2 WAF ルール

| ルール | アクション | 説明 |
|--------|----------|------|
| AWSManagedRulesCommonRuleSet | Block | 一般的な攻撃防御 |
| AWSManagedRulesKnownBadInputsRuleSet | Block | 既知の悪意のある入力 |
| AWSManagedRulesSQLiRuleSet | Block | SQLインジェクション |
| レートベース制限 | Block | 1000 req/5min |

---

## 8. 可用性・DR設計

### 8.1 可用性目標

| 項目 | 目標値 |
|------|--------|
| 可用性 | 99.9% |
| RPO (目標復旧時点) | 1時間 |
| RTO (目標復旧時間) | 4時間 |

### 8.2 マルチAZ構成

| コンポーネント | AZ数 | 冗長化方式 |
|---------------|------|-----------|
| ALB | 3 | 自動分散 |
| EKS | 3 | Pod分散 |
| Aurora | 2 | 自動フェイルオーバー |
| NAT Gateway | 3 | AZ毎に配置 |

### 8.3 バックアップ

| 対象 | 方式 | 頻度 | 保持期間 |
|------|------|------|----------|
| Aurora | 自動スナップショット | 日次 | 35日 |
| S3 | クロスリージョンレプリケーション | リアルタイム | 無期限 |
| EKS設定 | Velero | 日次 | 30日 |

---

## 9. コスト見積もり

### 9.1 月額コスト概算（Production）

| サービス | 仕様 | 月額(USD) |
|---------|------|-----------|
| EKS | クラスター + Fargate | $500 |
| Aurora | db.r6g.large x 2 | $400 |
| ALB | 1台 | $50 |
| NAT Gateway | 3台 | $150 |
| S3 | 500GB | $15 |
| CloudFront | 1TB転送 | $100 |
| **合計** | | **$1,215** |

### 9.2 コスト最適化施策

- [ ] Savings Plans の検討
- [ ] スポットインスタンス活用（開発環境）
- [ ] S3 Intelligent-Tiering の適用
- [ ] 未使用リソースの定期削除

---

## 10. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
