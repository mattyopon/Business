# 03. IAM・アイデンティティ設計指針

本書は、金融機関向け AWS クラウド共通基盤における IAM およびアイデンティティ管理の設計指針をまとめたものである。

---

## 1. 設計方針

- AWS IAM Identity Center を中心とした統合認証基盤
- 既存 Active Directory／Entra ID との連携
- 最小権限の原則に基づく Permission Set 設計
- 特権アクセスの厳格な管理（Break Glass、JIT）
- 監査証跡の完全性確保

---

## 2. アイデンティティソース

### 2-1. 想定パターン

| パターン | 説明 |
|----------|------|
| Entra ID 連携 | SAML 2.0 ／ SCIM によるユーザー・グループ同期 |
| オンプレ AD 連携 | AD Connector または AD FS による認証連携 |
| IAM Identity Center 内部ディレクトリ | 単独利用（小規模向け） |

### 2-2. 属性マッピング

- AD／Entra ID 上のグループを Permission Set にマッピング
- 属性マッピングの粒度（部署単位／プロジェクト単位／職位単位）は事前に決定
- 命名規則の標準化（例：`aws-{environment}-{role}` の形式）

---

## 3. Permission Set 設計

### 3-1. 標準セット

| 名称 | 用途 | 適用アカウント |
|------|------|----------------|
| Administrator | 緊急対応用の管理者 | 全アカウント（Break Glass） |
| PowerUser | 業務システムの開発者 | 開発／ステージング |
| ReadOnly | 監視・参照のみ | 全アカウント |
| Auditor | 監査担当者 | Audit アカウント |
| BillingAccess | 請求情報のアクセス | Management アカウント |
| NetworkAdmin | ネットワーク管理者 | Network アカウント |
| SecurityAdmin | セキュリティ管理者 | Audit アカウント |

### 3-2. 設計原則

- AWS マネージドポリシーを基盤とする
- 不足分はカスタマーマネージドポリシーで補う
- インラインポリシーは原則として使用しない
- セッション期間は業務に必要な最短時間に設定

---

## 4. Break Glass アクセス

### 4-1. 設計

- 各 OU／各環境ごとに専用の Break Glass 用 IAM ユーザーまたは Permission Set を用意
- 通常運用では使用しない
- 物理的なクレデンシャル保管（金庫等）
- MFA 必須

### 4-2. 利用プロセス

1. 利用前の承認（複数名による承認）
2. 利用時の即時通知（CloudWatch Events → SNS → 関係者通知）
3. 利用後 24 時間以内の経緯記録
4. 関係者レビュー（事後 1 週間以内）

---

## 5. Just-In-Time (JIT) アクセス

### 5-1. 設計

- 通常時は ReadOnly などの最小権限のみ
- 必要時に承認プロセスを経て、期限付きで権限を昇格
- AWS Systems Manager Session Manager によるアクセス記録
- セッション期間は最大 8 時間程度を上限とする

### 5-2. 自動化

- ServiceNow 等のチケットシステム連動による承認自動化を検討
- Permission Set の有効化／無効化を Lambda + EventBridge で実装

---

## 6. サービスロールおよびクロスアカウントロール

### 6-1. サービスロール

- AWS サービスがリソースにアクセスするためのロール
- 信頼ポリシーは該当サービスのみに限定
- 権限は必要最小限

### 6-2. クロスアカウントロール

- ExternalId による Confused Deputy 問題の防止
- 信頼関係は明示的に限定したアカウントのみ
- アクセスログ（CloudTrail）の集約および定期レビュー

---

## 7. ルートユーザー

- ルートユーザーは通常利用しない
- MFA を必須化
- パスワード変更後はパスワードマネージャー等で安全に保管
- 一部の操作（解約、リージョン制限解除 等）でのみルートユーザーが必要となるため、明確なプロセスを定義

---

## 8. IAM ベースライン

新規アカウント発行時に自動適用される標準セット。

- パスワードポリシー（最小長、複雑性、有効期限）
- MFA 必須化
- 標準 IAM ロール（CloudFormation 等が利用するロール）
- IAM Access Analyzer の有効化
- ルートユーザーアクセスキーの無効化

---

## 9. 監査および証跡

- CloudTrail の組織トレイルにより、全アカウントの API コールを Log Archive に集約
- AWS IAM Access Analyzer による外部アクセスの検出
- 定期的なアクセス権棚卸し（四半期ごと等）
- 退職者・異動者の権限失効プロセス

---

## 10. 関連リソース

- AWS IAM Identity Center: <https://docs.aws.amazon.com/singlesignon/>
- AWS IAM Best Practices: <https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html>
- AWS IAM Access Analyzer: <https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html>

---

**最終更新**: 2026-05-14
