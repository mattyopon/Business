# 想定Q&A - 検索システムインフラ構築支援案件

商談・面談時に想定される技術的な質問とその回答集です。

---

## 1. AWS基礎・経験

### Q: AWSの経験年数と主な担当業務を教えてください

**経験年数**: 約5年

**主な担当業務**:
- インフラ設計・構築（VPC、EC2、ECS、RDS、S3等）
- コンテナ基盤構築（ECS Fargate/EC2）
- CI/CDパイプライン構築（GitHub Actions）
- 24/365監視運用（New Relic、CloudWatch）
- セキュリティ対応（WAF、IAM、Inspector）

---

### Q: AWSの資格は持っていますか？

**取得歴**:
- AWS Certified Solutions Architect – Associate (2020年取得)
- AWS Certified Developer – Associate (2020年取得)
- AWS Certified SysOps Administrator – Associate (2020年取得)

> AWS 認定は取得から 3 年で再認定が必要です。2026 年 5 月時点の現役有効性は商談時に最新状況を共有し、再認定済みの場合は更新年も提示します。未更新であれば「取得歴」として位置付けています。

---

### Q: 直近のAWSプロジェクトを教えてください

**電車内広告配信システム（2023年8月〜2025年1月）**:
- CloudFront + WAF + ALBによるWebシステム構築
- ECS + EC2によるコンテナ基盤構築
- Lambda + ffmpegによる動画変換パイプライン
- GitHub Actionsを使用したCI/CD構築

**放送局グループMSP監視運用（2024年1月〜2025年6月）**:
- ECS Fargate環境の24/365監視運用
- New Relicによる監視設計・アラート設定
- IAMポリシー設計（最小権限の原則）

---

## 2. 設計・構築経験

### Q: VPC設計の経験を教えてください

**経験**:
- マルチAZ構成のVPC設計
- パブリック/プライベートサブネット分離
- NAT Gateway、Internet Gateway設計
- VPCピアリング設定
- セキュリティグループ/NACLの設計

**設計ポイント**:
- CIDR設計（将来の拡張性を考慮）
- サブネット分割（用途別：Web、App、DB、管理）
- ルートテーブル設計

---

### Q: コンテナ（ECS）の構築経験を教えてください

**経験**:
- ECS + EC2構成での構築・運用
- ECS Fargate構成での運用
- タスク定義、サービス定義の設計
- ALBとの連携（ターゲットグループ設定）
- Auto Scalingの設定

**実績**:
- 広告配信システム：ECS + EC2（Docker）でWordPress基盤構築
- 放送局システム：ECS Fargate環境の監視運用

---

### Q: インフラ構築で重視していることは何ですか？

1. **セキュリティ**
   - 最小権限の原則（IAM）
   - ネットワーク分離（プライベートサブネット活用）
   - 暗号化（転送時・保存時）

2. **可用性**
   - マルチAZ構成
   - Auto Scaling
   - ヘルスチェック設計

3. **運用性**
   - IaC（Terraform/CloudFormation）による管理
   - 監視・アラート設計
   - ドキュメント整備

4. **コスト最適化**
   - 適切なインスタンスサイズ選定
   - リザーブドインスタンス/Savings Plans検討
   - 不要リソースの削除

---

## 3. 認証・API管理

### Q: API Gatewayの経験はありますか？

**保有スキル**:
- REST / HTTP API の使い分け判断
- Lambda Proxy / カスタム統合の構成判断
- 認証方式（IAM / Cognito User Pool / API Key）の選定基準と Cognito Authorizer + JWT スコープ制御の設計
- ステージ管理 (dev/stg/prod) と Stage Variables / Usage Plan の運用設計
- スロットリング (RPS/Burst) と AWS WAF / CloudFront との層別防御

**実施済み検証 (本リポ同梱の Terraform で確認した範囲)**:
- `技術検証/terraform-aws-search/main.tf` に **REST API + リソース 1本 (`/search` GET) + Cognito Authorizer + Cognito User Pool / App Client** を IaC 化。**Lambda 統合 / API ステージ・デプロイ / Usage Plan / OAuth スコープ強制 / WAF / Hosted UI は本デモには未実装** で、本デモは「認可フローと Terraform 構造を確認するための最小サンプル」の位置付け
- `参画用/運用ドキュメント/03_API-Gateway設計書.md` で本案件向けの API 設計 / スロットリング / 認可 / ロギングを文書化 (実装は本案件で並走実施)

**前職での直接実装の経験範囲**:
- 大規模商用 API の運用は New Relic / CloudWatch 監視と障害対応が中心。新規 API Gateway の0→1構築は本案件と同等規模では未経験のため、初期スプリントはチームリードと並走しながら設計判断をコミットする想定です。

---

### Q: Cognitoの経験はありますか？

**保有スキル**:
- User Pool / Identity Pool の役割分担と選定 (本案件は User Pool + API Gateway Authorizer 構成を想定)
- OAuth 2.0 / OIDC スコープ設計、トークン有効期限、Refresh Token Revoke 戦略
- MFA (SMS / TOTP) 設定、管理者ロール強制、リスクベース認証
- 認証フロー (USER_SRP_AUTH / REFRESH_TOKEN_AUTH) の使い分け、Client Secret の有効/無効の判断

**実施済み検証 (本リポ同梱の Terraform で確認した範囲)**:
- `技術検証/terraform-aws-search/main.tf` で User Pool (password policy 12文字以上 / MFA OPTIONAL / アカウント復旧 verified_email) + App Client (SRP / Refresh Token 認証フロー) + API Gateway Authorizer の最小構成を IaC 化
- **Hosted UI / Identity Pool / Cognito Groups / OAuth スコープ強制 / カスタムリソースサーバ / Triggers (Lambda hook) は本デモには未実装**。本デモは「ユーザープールと Authorizer の Terraform 構造確認」の最小サンプルです
- IAM Identity Center 経由の運用者認証は前職にて本番運用経験あり

**前職での直接実装の経験範囲**:
- 商用サービスの Cognito 新規導入は本案件と同等規模では未経験。実装中の設計判断は AWS Well-Architected の Security Pillar / 公式ガイドに沿って進め、不確実領域は AWS サポート (Business 以上) と並走しながら詰めます。

---

## 4. ネットワーク・ストレージ

### Q: ネットワーク設計の経験を教えてください

**経験**:
- VPC設計（CIDR、サブネット、ルートテーブル）
- セキュリティグループ/NACLの設計
- ALB/NLB設定
- CloudFront設定
- VPCピアリング

**実績**:
- 広告配信システム：CloudFront + ALB + EC2の構成設計
- 放送局システム：Fastly CDN + AWS環境のネットワーク設計

---

### Q: ストレージの経験を教えてください

**S3**:
- バケット作成・ポリシー設定
- ライフサイクルポリシー設定
- 静的Webサイトホスティング
- CloudFrontとの連携

**EBS**:
- ボリュームタイプ選定（gp2/gp3）
- スナップショット管理
- 暗号化設定

**EFS**:
- マウントターゲット設定
- パフォーマンスモード選定

---

## 5. 検索システム関連

### Q: OpenSearch/Elasticsearchの経験はありますか？

**保有スキル**:
- インデックス / シャード / レプリカ設計、JVM ヒープサイズと shard 数の関係
- マッピング設計 (text / keyword / completion フィールド分離、kuromoji + filter 連鎖)
- クエリ DSL (match / term / bool / range / aggregations / completion suggester) の使い分け
- スロークエリ調査と最適化 (`SearchLatency` p95, slow log threshold 設定)
- 監査ログ / SigV4 認証 / FGAC / KMS 暗号化など Managed OpenSearch 固有の運用ポイント

**実施済み検証 (本リポ同梱の範囲)**:
- `技術検証/opensearch-demo/README.md` に kuromoji analyzer / completion suggester (mapping 修正済) / aggregations / bool query を含む**マッピング設計とクエリ DSL のスニペット集**を整備。実機実行は本案件参画時に並走
- `技術検証/terraform-aws-search/main.tf` で Managed Domain (VPC内 / FGAC enabled / KMS CMK 暗号化 / TLS 1.2 enforce / Slow Log 3種類取込) の **最小構成**を実装。マルチノード dedicated master / Hot-Warm tier / Snapshot Lifecycle / Index State Management は本デモのスコープ外
- `参画用/運用ドキュメント/02_OpenSearch運用ガイド.md` で SigV4 (awscurl / curl --aws-sigv4 / opensearch-py + AWS4Auth) を含む運用手順を文書化

**前職での直接実装の経験範囲**:
- 商用 OpenSearch クラスタの新規構築は本案件と同等規模では未経験。本案件では「設計判断と運用文書化」「Terraform IaC 化」「監視設計」を中心にコミットし、初期インデックス設計とクエリチューニングはアプリケーション開発チームとペアで進めたいと考えています。

---

### Q: 検索システムの構築で重要だと考えることは？

1. **可用性**
   - マルチAZ構成
   - レプリカ設定
   - Auto Scaling

2. **パフォーマンス**
   - 適切なシャード数設計
   - キャッシュ活用（ElastiCache）
   - クエリ最適化

3. **運用性**
   - インデックス管理（ライフサイクル）
   - 監視・アラート設計
   - バックアップ・リストア手順

4. **セキュリティ**
   - VPC内配置
   - アクセス制御（IAM、セキュリティグループ）
   - 暗号化（転送時・保存時）

---

## 6. 運用・監視

### Q: 監視設計の経験を教えてください

**使用ツール**:
- New Relic APM/Infrastructure
- Zabbix
- CloudWatch
- Fastly Dashboard

**担当業務**:
- アラート設計（閾値設定、エスカレーション）
- ダッシュボード作成
- Runbook作成
- 障害対応フロー設計

**実績**:
放送局グループ案件で24/365監視運用を担当。複数サービスの監視基盤を設計・運用。

---

### Q: 障害対応の経験を教えてください

**対応経験**:
- サービス停止時の一次対応
- ログ調査（CloudWatch Logs、アプリログ）
- エスカレーション判断
- 復旧確認・報告

**整備したもの**:
- Runbook（障害別の対応手順）
- エスカレーションルール
- 報告テンプレート

---

## 7. IaC（Infrastructure as Code）

### Q: Terraformの経験はありますか？

**経験レベル**: 基礎〜中級

**経験内容**:
- VPC、サブネット、セキュリティグループ定義
- EC2、ECS、RDS等のリソース定義
- モジュール化
- tfstateのリモート管理（S3 + DynamoDB）

**補足**:
検証レベルでの使用経験があります。実務ではCloudFormationも併用。

---

### Q: CloudFormationの経験はありますか？

**経験レベル**: 基礎

**経験内容**:
- テンプレート作成（YAML）
- スタックの作成・更新・削除
- パラメータ、アウトプットの設定

---

## 8. チーム・コミュニケーション

### Q: チームでの働き方を教えてください

**経験**:
- チームリード経験（設計レビュー、メンバー育成）
- クライアント調整

**コミュニケーション**:
- Slack/Teamsでの日常的なコミュニケーション
- 技術ドキュメントの作成・共有
- 障害時のエスカレーション

---

### Q: 技術的な課題をどのように解決しますか？

1. **情報収集**: 公式ドキュメント、技術ブログ
2. **検証**: 検証環境での動作確認
3. **相談**: チームメンバー、有識者への相談
4. **記録**: 解決策のドキュメント化

---

## 9. 本案件への意気込み

### Q: なぜこの案件に興味を持ちましたか？

1. **AWS経験の活用**
   - 5年間のAWS経験を活かせる
   - 設計〜構築という自分の得意領域

2. **新しい技術への挑戦**
   - 検索システム（OpenSearch等）の実務経験を積みたい
   - API管理、認証系の経験を深めたい

3. **スキルアップ**
   - 設計から構築まで一貫して担当できる

---

### Q: 不足しているスキルはどのように補いますか？

1. **自己学習**
   - AWS公式ドキュメント
   - ハンズオン検証

2. **チームとの連携**
   - 有識者への質問
   - レビューを通じた学習

3. **継続的改善**
   - 振り返り、ナレッジ蓄積

---

## 関連資料

| 資料 | 説明 |
|------|------|
| [技術用語解説](技術用語解説.md) | 技術用語の解説 |
| [ヒアリングシート](ヒアリングシート.md) | 商談時の確認項目 |
