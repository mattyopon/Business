# IaC（Infrastructure as Code）運用ガイドライン

## 1. 概要

### 1.1 目的
本ドキュメントは、Terraform/CloudFormationを使用したインフラ管理の運用ルールを定義する。

### 1.2 対象ツール
- **Terraform**: マルチクラウド対応IaCツール（メイン）
- **CloudFormation**: AWS固有の機能で使用

### 1.3 適用範囲
- 全AWSリソース
- 全環境（Production, Staging, Development）

---

## 2. ディレクトリ構成

### 2.1 推奨構成

```
infrastructure/
├── terraform/
│   ├── modules/                    # 再利用可能なモジュール
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── eks/
│   │   ├── aurora/
│   │   ├── s3/
│   │   └── monitoring/
│   │
│   ├── environments/               # 環境別設定
│   │   ├── production/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   ├── staging/
│   │   └── development/
│   │
│   └── shared/                     # 共有リソース
│       ├── iam/
│       ├── kms/
│       └── ecr/
│
├── cloudformation/                 # CFn固有テンプレート
│   └── stacksets/
│
└── scripts/                        # ユーティリティスクリプト
    ├── plan.sh
    ├── apply.sh
    └── destroy.sh
```

### 2.2 命名規則

| リソース | 命名パターン | 例 |
|---------|-------------|-----|
| VPC | {project}-{env}-vpc | medical-ai-prod-vpc |
| Subnet | {project}-{env}-{public/private}-{az} | medical-ai-prod-private-1a |
| Security Group | {project}-{env}-{service}-sg | medical-ai-prod-eks-sg |
| IAM Role | {project}-{env}-{service}-role | medical-ai-prod-eks-role |
| S3 Bucket | {project}-{env}-{purpose} | medical-ai-prod-models |

---

## 3. 開発フロー

### 3.1 変更フロー

```
1. Issue作成
   ↓
2. Feature Branch作成
   git checkout -b feature/add-aurora-cluster
   ↓
3. コード修正
   ↓
4. ローカルでplan確認
   terraform plan -var-file=terraform.tfvars
   ↓
5. Pull Request作成
   ↓
6. コードレビュー
   - terraform fmtチェック
   - terraform validateチェック
   - セキュリティスキャン（tfsec）
   ↓
7. Staging環境でapply
   ↓
8. 動作確認
   ↓
9. Production環境でapply
   ↓
10. マージ & Issue Close
```

### 3.2 ブランチ戦略

| ブランチ | 用途 | 保護 |
|---------|------|------|
| main | 本番コード | Protected |
| staging | ステージング検証 | Protected |
| feature/* | 機能開発 | - |
| hotfix/* | 緊急修正 | - |

---

## 4. Terraformコーディング規約

### 4.1 ファイル構成

```hcl
# main.tf - リソース定義
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

# variables.tf - 変数定義
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

# outputs.tf - 出力定義
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

# locals.tf - ローカル変数
locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

### 4.2 コーディングルール

```hcl
# 良い例
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type

  # メタ引数は最初に
  count = var.instance_count

  # ブロックは最後に
  tags = {
    Name = "${local.name_prefix}-web"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 悪い例（避けるべき）
resource "aws_instance" "web" {
  tags = { Name = "web" }  # ハードコード
  ami = "ami-12345"        # ハードコード
  instance_type = "t3.micro"
}
```

### 4.3 モジュール設計原則

```hcl
# モジュール呼び出し例
module "vpc" {
  source = "../../modules/vpc"

  # 必須変数
  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr

  # オプション変数（デフォルト値あり）
  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"

  # 共通タグ
  tags = local.common_tags
}
```

---

## 5. 状態管理

### 5.1 Remote State設定

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "medical-ai-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### 5.2 State分離戦略

| 状態ファイル | 対象リソース |
|-------------|-------------|
| shared/terraform.tfstate | IAM, KMS, ECR |
| production/terraform.tfstate | 本番環境リソース |
| staging/terraform.tfstate | ステージング環境リソース |
| development/terraform.tfstate | 開発環境リソース |

### 5.3 State操作ルール

```bash
# State操作は原則禁止。必要な場合は2名以上で実施

# リソースの移動
terraform state mv aws_instance.old aws_instance.new

# リソースの削除（Stateから除外）
terraform state rm aws_instance.manual

# State確認
terraform state list
terraform state show aws_instance.web
```

---

## 6. セキュリティ

### 6.1 機密情報の管理

```hcl
# 悪い例（絶対にやらない）
resource "aws_db_instance" "db" {
  password = "hardcoded_password"  # NG!
}

# 良い例（Secrets Manager使用）
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "medical-ai/production/db-password"
}

resource "aws_db_instance" "db" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# 良い例（変数で受け取り、CI/CDで注入）
resource "aws_db_instance" "db" {
  password = var.db_password  # terraform.tfvarsには書かない
}
```

### 6.2 セキュリティスキャン

```yaml
# .github/workflows/terraform-security.yml
name: Terraform Security Scan

on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  tfsec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: terraform/

      - name: Run checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform
```

### 6.3 最小権限IAMポリシー

```hcl
# Terraform実行用IAMポリシー
data "aws_iam_policy_document" "terraform" {
  # 必要なリソースのみに限定
  statement {
    effect = "Allow"
    actions = [
      "ec2:*",
      "rds:*",
      "eks:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-northeast-1"]
    }
  }

  # State管理用
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::medical-ai-terraform-state/*"
    ]
  }
}
```

---

## 7. CI/CD統合

### 7.1 GitHub Actions ワークフロー

```yaml
name: Terraform CI/CD

on:
  push:
    branches: [main, staging]
    paths:
      - 'terraform/**'
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'

env:
  TF_VERSION: 1.5.0
  AWS_REGION: ap-northeast-1

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform fmt
        run: terraform fmt -check -recursive

      - name: Terraform validate
        run: |
          cd terraform/environments/production
          terraform init -backend=false
          terraform validate

  plan:
    needs: validate
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Plan
        run: |
          cd terraform/environments/production
          terraform init
          terraform plan -out=tfplan

      - name: Post Plan to PR
        uses: actions/github-script@v7
        with:
          script: |
            // PR にplan結果をコメント

  apply-staging:
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/staging'
    environment: staging
    steps:
      - name: Terraform Apply (Staging)
        run: |
          cd terraform/environments/staging
          terraform init
          terraform apply -auto-approve

  apply-production:
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Terraform Apply (Production)
        run: |
          cd terraform/environments/production
          terraform init
          terraform apply -auto-approve
```

---

## 8. 運用手順

### 8.1 日常オペレーション

```bash
# 1. 変更確認
cd terraform/environments/production
terraform plan -var-file=terraform.tfvars

# 2. 変更適用（承認後）
terraform apply -var-file=terraform.tfvars

# 3. 出力確認
terraform output

# 4. リソース一覧確認
terraform state list
```

### 8.2 ドリフト検出

```bash
# ドリフト検出
terraform plan -detailed-exitcode

# Exit code:
# 0 = 変更なし
# 1 = エラー
# 2 = 変更あり（ドリフト検出）
```

### 8.3 ロールバック手順

```bash
# 1. 前バージョンのコードをチェックアウト
git checkout HEAD~1 -- terraform/

# 2. Plan確認
terraform plan

# 3. Apply（ロールバック）
terraform apply

# または、git revertを使用
git revert HEAD
git push origin main
```

---

## 9. トラブルシューティング

### 9.1 よくある問題と対処

| 問題 | 原因 | 対処 |
|------|------|------|
| State Lock | 前回の実行が中断 | `terraform force-unlock <LOCK_ID>` |
| リソース競合 | 手動変更との競合 | `terraform refresh` → plan確認 |
| Provider Error | 認証切れ | AWS認証情報を更新 |
| Module Not Found | パス間違い | sourceパスを確認 |

### 9.2 デバッグ方法

```bash
# 詳細ログ出力
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log

terraform plan

# ログ確認後、環境変数をクリア
unset TF_LOG TF_LOG_PATH
```

---

## 10. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |
