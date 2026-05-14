# 05. IaC・CI/CD 設計指針

本書は、金融機関向け AWS クラウド共通基盤における Infrastructure as Code (IaC) および CI/CD パイプラインの設計指針をまとめたものである。

---

## 1. 設計方針

- すべての AWS リソースを IaC で管理（クリック運用の排除）
- バージョン管理（Git）による変更履歴の保持
- 静的解析によるセキュリティ・コンプライアンスチェックの自動化
- CAB と連動した承認ゲートによる本番変更の統制
- ロールバック可能なデプロイ方式

---

## 2. IaC ツールの選定

### 2-1. 標準ツール

| ツール | 適用範囲 |
|--------|----------|
| Terraform | 共通基盤および利用システムの標準 |
| AWS CloudFormation | AWS Control Tower／LZA の管理範囲（強制的に併用） |
| AWS CDK | プログラム可能性が必要な箇所（オプション） |

### 2-2. 選定基準

- 既存スキルセットとの整合性
- マルチクラウドの可能性
- AWS 新サービスへの追従性
- コミュニティ／ベンダーサポート

---

## 3. Terraform 運用

### 3-1. ディレクトリ構成

```
infrastructure/
├── modules/                # 再利用可能モジュール
│   ├── vpc/
│   ├── ec2/
│   └── ...
├── accounts/               # アカウント別の構成
│   ├── shared-services/
│   ├── workloads-prod/
│   └── ...
└── environments/           # 環境別の構成
    ├── dev/
    ├── staging/
    └── prod/
```

### 3-2. 状態管理

- バックエンド: S3 + DynamoDB（ロック）
- 状態ファイルは暗号化（SSE-KMS、CMK 利用）
- 状態ファイルへのアクセス権限は最小化
- アカウント／環境別に分離

### 3-3. モジュール設計

- 再利用可能な単位でモジュール化
- バージョン管理（Git タグ）
- インプット／アウトプットの仕様を明文化
- ドキュメンテーション（README）の整備

---

## 4. 静的解析

### 4-1. 採用ツール

| ツール | 対象 | 役割 |
|--------|------|------|
| tfsec | Terraform | セキュリティ設定不備の検出 |
| Checkov | Terraform／CloudFormation／Kubernetes | マルチクラウド対応のポリシー検出 |
| cdk-nag | AWS CDK | CDK 出力のセキュリティチェック |
| cfn-nag | CloudFormation | CloudFormation のセキュリティチェック |
| terraform fmt | Terraform | フォーマット |
| terraform validate | Terraform | 構文検証 |

### 4-2. 実行タイミング

- ローカル開発時: pre-commit hook
- Pull Request 時: CI で自動実行
- マージ前: 必須通過要件

### 4-3. 検出結果の取り扱い

- 検出結果を GitHub Code Scanning に統合（SARIF 形式）
- High／Critical はマージブロック
- Medium／Low は警告のみ
- 例外承認プロセス（除外ファイルへの追加には承認が必要）

---

## 5. CI/CD パイプライン

### 5-1. 採用ツール

| ツール | 適用 |
|--------|------|
| GitHub Actions | 標準採用 |
| AWS CodePipeline | AWS マネージドな選択肢として併用可能 |

### 5-2. 認証方式

- GitHub Actions: OIDC を用いた AWS への認証（IAM ロール引受）
- アクセスキーの長期保持は禁止

### 5-3. パイプライン構成

```
Pull Request 作成
  ↓
[CI ステージ]
  - 静的解析（tfsec、Checkov）
  - terraform fmt／validate
  - plan の実行
  - plan 結果の PR コメント
  ↓
コードレビュー（2 名以上の承認）
  ↓
マージ
  ↓
[CD ステージ - 開発環境]
  - terraform apply（自動）
  ↓
[CD ステージ - ステージング環境]
  - terraform apply（自動）
  ↓
[CD ステージ - 本番環境]
  - CAB 承認
  - 手動承認ゲート
  - terraform apply
  - 事後検証
```

---

## 6. シークレット管理

### 6-1. 標準サービス

- AWS Secrets Manager: 自動ローテーション可能、データベース認証情報など
- AWS Systems Manager Parameter Store: 軽量な設定情報、機密度の低い情報

### 6-2. 設計原則

- IaC コード内にシークレットをハードコードしない
- リポジトリへのシークレット混入を防止（`git-secrets`、`detect-secrets` 等）
- アクセス権限は最小化
- ローテーション頻度の明文化（最低年 1 回）

---

## 7. 承認ゲートおよび変更管理

### 7-1. 通常変更

- CAB（Change Advisory Board）による事前承認
- 影響度（高／中／低）に応じた承認レベル
- ChangeRecord の作成（ServiceNow 等）

### 7-2. 緊急変更

- Emergency Change の経路を別途用意
- 事後 CAB レビュー必須
- 障害発生時の対応として明文化

### 7-3. 標準変更

- 事前承認済みのテンプレート変更
- 承認不要で実施可能
- 標準変更カタログを整備

---

## 8. ロールバック

### 8-1. Terraform

- 直前のコミットへ revert
- terraform plan で差分確認後に apply

### 8-2. アプリケーション

- ブルーグリーンデプロイメント（ALB／ターゲットグループ切替）
- カナリアデプロイメント（重み付け切替）
- ロールバック手順を Runbook 化

---

## 9. パッケージ管理

### 9-1. AWS CodeArtifact

- npm／Maven／PyPI／NuGet のリポジトリ
- 外部リポジトリのプロキシキャッシュ
- 利用ライブラリの SBOM 管理

### 9-2. コンテナイメージ

- Amazon ECR をプライベートレジストリとして利用
- イメージスキャン（Amazon Inspector）の有効化
- イメージ署名（AWS Signer）の検討

---

## 10. 関連リソース

- AWS Prescriptive Guidance (DevOps): <https://aws.amazon.com/prescriptive-guidance/>
- AWS CodePipeline: <https://docs.aws.amazon.com/codepipeline/>
- AWS Secrets Manager: <https://docs.aws.amazon.com/secretsmanager/>
- Terraform AWS Provider: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>

---

**最終更新**: 2026-05-14
