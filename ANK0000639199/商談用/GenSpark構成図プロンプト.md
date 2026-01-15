# GenSpark 資料作成用プロンプト

## 概要

このドキュメントは、医療AIプラットフォームのシステム提案資料をGenSparkで作成するためのプロンプト集です。
Terraformコードおよび設計ドキュメントの内容を正確に反映するよう設計されています。

---

## プロンプト1: PowerPoint提案資料の作成

以下のプロンプトをGenSparkにコピー＆ペーストしてください。

```
医療AIプラットフォームのインフラ提案資料をPowerPoint形式で作成してください。

【プロジェクト概要】
- プロジェクト名: 医療AIプラットフォーム
- リージョン: ap-northeast-1（東京）
- 環境: Production / Staging / Development の3環境構成
- 設計原則: AWS Well-Architected Framework準拠、高可用性99.9%以上、セキュリティファースト

【システム構成（正確に反映してください）】

■ ネットワーク層
- VPC CIDR: 10.0.0.0/16（本番）、10.1.0.0/16（検証）、10.2.0.0/16（開発）
- Public Subnet: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24（3AZ）
- Private Subnet: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24（3AZ）
- NAT Gateway: 各AZに配置（本番）、1つ（開発・コスト削減）
- VPC Flow Logs: 有効

■ フロントエンド層
- CloudFront: CDN、SSL/TLS終端
- WAF:
  - AWSManagedRulesCommonRuleSet
  - AWSManagedRulesSQLiRuleSet
  - レートベース制限（1000 req/5min）

■ アプリケーション層
- Application Load Balancer: Public Subnetに配置
- EKS (Fargate): Kubernetes 1.28
  - Fargate Profile: default, kube-system, mlops
  - Pod種類: API Pod, ML Inference Pod, Worker Pod
- クラスターログ: api, audit, authenticator

■ データ層
- Aurora MySQL 8.0: Multi-AZ構成
  - インスタンスクラス: db.r6g.large（本番）、db.t3.medium（開発）
  - 暗号化: KMS
  - バックアップ保持: 35日
- S3: MLモデル保存
  - バージョニング: 有効
  - 暗号化: SSE-KMS
  - パブリックアクセス: 完全ブロック

■ コンテナレジストリ
- ECR: Dockerイメージ保存

【セキュリティ要件】
- 医療データ（PHI）対応
- 3省2ガイドライン準拠
- 全通信の暗号化（転送時・保存時）
- IAMによるアクセス制御
- 監査ログの保持

【コスト概算（月額・本番環境）】
- EKS (クラスター + Fargate): $500
- Aurora (db.r6g.large x 2): $400
- ALB: $50
- NAT Gateway (3台): $150
- S3 (500GB): $15
- CloudFront (1TB転送): $100
- 合計: 約$1,215/月

【スライド構成（10枚程度）】
1. 表紙
2. プロジェクト概要・目的
3. システム全体構成図（視覚的にわかりやすく）
4. ネットワーク設計（VPC、サブネット構成）
5. アプリケーション層（EKS + Fargate）
6. データ層（Aurora + S3）
7. セキュリティ対策
8. 監視・運用体制
9. コスト見積もり
10. 今後のロードマップ

【デザイン要件】
- AWS公式カラーを使用（オレンジ: #FF9900）
- AWSアイコンを使用
- 図は視覚的にシンプルに
- 専門用語には簡単な説明を併記
```

---

## プロンプト2: システム構成図のみ作成

```
以下の仕様でAWSシステム構成図を作成してください。draw.io形式またはPNG画像で出力してください。

【構成要素】
ユーザー → CloudFront + WAF → ALB → EKS (Fargate) → Aurora MySQL
                                      ↓
                                     S3 (MLモデル)
                                     ECR (コンテナイメージ)

【詳細】
1. VPC (10.0.0.0/16)
   - Public Subnet x 3 (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
   - Private Subnet x 3 (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)

2. Public Subnetに配置
   - ALB
   - NAT Gateway

3. Private Subnetに配置
   - EKS Cluster (Fargate)
     - API Pod
     - ML Inference Pod
     - Worker Pod
   - Aurora MySQL (Multi-AZ)

4. リージョン外
   - CloudFront
   - WAF
   - S3
   - ECR

【表示要件】
- AWSアイコンを使用
- セキュリティグループの境界を点線で表示
- データフローを矢印で表示
- 各コンポーネントにラベルを付与
```

---

## プロンプト3: コスト詳細資料

```
以下のAWSリソース構成のコスト詳細資料を作成してください。

【本番環境リソース一覧】
| サービス | 仕様 | 数量 |
|---------|------|------|
| EKS | クラスター | 1 |
| Fargate | vCPU 0.5, メモリ 1GB | 8 Pod |
| Aurora MySQL | db.r6g.large | 2 (Writer + Reader) |
| ALB | - | 1 |
| NAT Gateway | - | 3 |
| S3 | 500GB, SSE-KMS | 1 |
| CloudFront | 1TB転送/月 | 1 |
| WAF | WebACL | 1 |
| VPC Flow Logs | - | 1 |

【出力形式】
1. 月額コスト内訳表
2. 年間コスト見積もり
3. コスト最適化の提案
   - Savings Plans
   - スポットインスタンス（開発環境）
   - S3 Intelligent-Tiering
4. 環境別コスト比較（本番/検証/開発）
```

---

## プロンプト4: セキュリティ構成図

```
医療AIプラットフォームのセキュリティ構成図を作成してください。

【セキュリティ要件】
- 医療データ（PHI: Protected Health Information）を扱う
- 3省2ガイドライン（厚生労働省、経済産業省、総務省）準拠
- 個人情報保護法対応

【セキュリティ対策】
1. ネットワークセキュリティ
   - WAF: SQLインジェクション、XSS対策
   - Security Group: 最小権限の原則
   - Private Subnet: データベースはインターネットから隔離

2. データ暗号化
   - 転送時: TLS 1.2以上
   - 保存時: KMS暗号化（Aurora、S3）

3. アクセス制御
   - IAM: ロールベースアクセス制御
   - Secrets Manager: 認証情報管理

4. 監査・ログ
   - CloudTrail: API監査ログ
   - VPC Flow Logs: ネットワークログ
   - EKS監査ログ: api, audit, authenticator

【出力形式】
- セキュリティ境界を示した構成図
- 暗号化ポイントの明示
- アクセス制御フローの矢印
```

---

## プロンプト5: 経営層向けサマリー（1枚）

```
以下の内容を1枚のエグゼクティブサマリーにまとめてください。

【プロジェクト名】
医療AIプラットフォーム インフラ構築

【解決する課題】
- AIモデルを本番環境で安定稼働させる基盤がない
- 医療データを扱うためのセキュリティ要件への対応
- スケーラブルなインフラの必要性

【提案内容】
- AWSクラウド上にセキュアなAI実行基盤を構築
- コンテナ技術（EKS）による柔軟なスケーリング
- 医療データガバナンス対応（3省2ガイドライン）

【期待効果】
- 可用性99.9%以上の安定稼働
- 自動スケーリングによる効率的なリソース利用
- セキュリティ・コンプライアンス要件の充足

【投資額】
- 初期構築: 一時費用
- 月額運用: 約$1,215（約18万円）※本番環境

【デザイン】
- A4横1枚
- 図と箇条書きで視覚的に
- 専門用語は最小限に
```

---

## 注意事項

### GenSparkへの指示のコツ

1. **数値は正確に**: CIDR、ポート番号、インスタンスタイプは変更しない
2. **AWSアイコン指定**: 「AWS公式アイコンを使用」と明記
3. **出力形式を指定**: PowerPoint、PNG、draw.io等
4. **対象者を明示**: 技術者向け/経営者向けで詳細度を調整

### 差異が出やすいポイント

| 項目 | 正しい値 | よくある間違い |
|------|---------|---------------|
| Kubernetes版 | 1.28 | 1.27, 1.29 |
| Aurora版 | MySQL 8.0 | PostgreSQL |
| VPC CIDR | 10.0.0.0/16 | 172.16.0.0/16 |
| リージョン | ap-northeast-1 | us-east-1 |
| Fargate Profile | default, kube-system, mlops | app |

### Terraformコードとの整合性確認

資料作成後、以下のファイルと照合して差異がないか確認してください：
- `技術検証/terraform-aws-infra/environments/dev/main.tf`
- `参画用/運用ドキュメント/01_AWSインフラ設計書.md`
