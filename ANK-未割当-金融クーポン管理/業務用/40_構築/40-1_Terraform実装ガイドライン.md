# 40-1. Terraform 実装ガイドライン

**目的**: Terraform による IaC 実装のルール・パターンを統一する。Codex レビューと監査に耐える品質を確保。

---

## 1. バージョン・前提

| 項目 | バージョン |
|---|---|
| Terraform | ~> 1.10 |
| hashicorp/aws Provider | ~> 5.100 |
| hashicorp/random Provider | ~> 3.6 |
| hashicorp/null Provider | ~> 3.2 |

```hcl
terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}
```

> バージョン固定により設計時と構築時の差異を防止 (R-E04 リスク回避)。

---

## 2. ディレクトリ構造

```
terraform/
├── modules/                      # 再利用可能モジュール
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   ├── ecs/
│   ├── aurora/
│   ├── s3/
│   ├── iam/
│   ├── route53/
│   ├── monitoring/
│   └── change_calendar/
├── environments/                 # 環境別構成
│   ├── mut/
│   │   ├── main.tf              # モジュール呼出
│   │   ├── variables.tf
│   │   ├── terraform.tfvars     # 環境別パラメータ
│   │   ├── backend.tf
│   │   └── versions.tf
│   ├── lt/
│   ├── st/
│   ├── dev-it/
│   └── prod/
├── global/                       # 全環境共通 (KMS, Route 53 Zone 等)
│   ├── kms/
│   ├── route53/
│   └── ecr/
└── .github/                      # GitHub Actions (or .gitlab-ci.yml)
    └── workflows/
        ├── terraform-plan.yml
        └── terraform-apply.yml
```

---

## 3. State 管理

### 3.1 Remote Backend
- S3 + DynamoDB (Lock)
- 環境別 / レイヤー別に State 分離

```hcl
terraform {
  backend "s3" {
    bucket         = "coupon-prod-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    kms_key_id     = "alias/coupon-prod-tf-state"
    dynamodb_table = "coupon-prod-tf-state-lock"
  }
}
```

### 3.2 State 分割ルール
- 環境別 (mut / lt / st / dev-it / prod)
- レイヤー別 (network / app / data) — 大規模化したら分離検討
- 影響範囲を最小化

### 3.3 State 保護
- S3 Versioning ON
- Cross-region Replication (大阪)
- Object Lock GOVERNANCE
- 手動編集禁止 (terraform state mv のみ)

---

## 4. コーディング規約

### 4.1 命名規則
- リソース名: `{案件}-{環境}-{用途}` (`coupon-prod-aurora-cluster` 等)
- Terraform リソース識別子: snake_case (`aws_rds_cluster.coupon_aurora`)
- variable: snake_case
- output: snake_case
- module: snake_case

### 4.2 ファイル構成 (1 モジュール内)
- `main.tf` — リソース定義
- `variables.tf` — 入力変数
- `outputs.tf` — 出力
- `versions.tf` — Terraform / Provider 版
- `README.md` — モジュール使い方
- `data.tf` — data ソース (大量にあれば分離)
- `locals.tf` — locals (大量にあれば分離)

### 4.3 タグ
全リソースに必須タグ (default_tags 利用):

```hcl
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project            = "coupon"
      Environment        = var.env
      Owner              = "coupon-team"
      CostCenter         = var.cost_center
      DataClassification = "confidential"
      ManagedBy          = "terraform"
      Repository         = var.repo_url
    }
  }
}
```

### 4.4 variable 定義
- type 必須
- description 必須
- 制約条件は validation で明示

```hcl
variable "instance_class" {
  type        = string
  description = "Aurora インスタンスクラス"
  default     = "db.r6g.large"
  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "instance_class は db. で始まる必要があります。"
  }
}
```

### 4.5 output 定義
- description 必須
- 機密値は sensitive = true

```hcl
output "aurora_endpoint" {
  description = "Aurora Cluster Writer Endpoint"
  value       = aws_rds_cluster.this.endpoint
  sensitive   = false
}
```

### 4.6 機密情報
- ハードコード禁止
- Secrets Manager / SSM Parameter Store 経由
- `sensitive = true` 設定

### 4.7 コメント
- WHY を書く、WHAT は書かない
- リソース固有の制約 (例: Aurora 暗号化は作成時固定) を明示

---

## 5. モジュール設計

### 5.1 モジュール責務
- 単一責務 (例: VPC モジュールは VPC + Subnet のみ、Route 53 は別)
- variables で外部依存を明示
- outputs で他モジュールに必要な値を公開
- バージョン管理 (Tag) を必須化

### 5.2 モジュール例 (modules/aurora/main.tf 抜粋)

```hcl
resource "aws_rds_cluster" "this" {
  cluster_identifier              = "${var.prefix}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = var.engine_version
  database_name                   = var.database_name
  master_username                 = var.master_username
  manage_master_user_password     = true
  master_user_secret_kms_key_id   = var.kms_key_arn
  
  storage_encrypted               = true
  kms_key_id                      = var.kms_key_arn       # 構築時固定、変更不可
  
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = var.security_group_ids
  
  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = var.backup_window
  preferred_maintenance_window    = var.maintenance_window
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = !var.deletion_protection
  final_snapshot_identifier       = var.deletion_protection ? "${var.prefix}-final-snapshot-${formatdate("YYYYMMDD", timestamp())}" : null

  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  
  performance_insights_enabled        = var.performance_insights_enabled
  performance_insights_kms_key_id     = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_retention_period
  
  iam_database_authentication_enabled = true
  
  lifecycle {
    ignore_changes = [
      master_username,
      final_snapshot_identifier,
    ]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count
  
  identifier                            = "${var.prefix}-aurora-${count.index + 1}"
  cluster_identifier                    = aws_rds_cluster.this.id
  instance_class                        = var.instance_class
  engine                                = aws_rds_cluster.this.engine
  engine_version                        = aws_rds_cluster.this.engine_version
  
  db_parameter_group_name               = aws_db_parameter_group.this.name
  monitoring_interval                   = var.enhanced_monitoring_interval
  monitoring_role_arn                   = var.enhanced_monitoring_role_arn
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_retention_period
  
  auto_minor_version_upgrade            = false
}
```

> 出典: AWS Provider Documentation https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster

---

## 6. 環境別構成

### 6.1 environments/{env}/main.tf 例

```hcl
locals {
  env = "prod"
}

module "vpc" {
  source = "../../modules/vpc"
  
  prefix = "coupon-${local.env}"
  vpc_cidr = var.vpc_cidr
  az_count = 3
  # ...
}

module "kms" {
  source = "../../modules/kms"
  
  prefix = "coupon-${local.env}"
  multi_region = true
  # ...
}

module "aurora" {
  source = "../../modules/aurora"
  
  prefix          = "coupon-${local.env}"
  vpc_id          = module.vpc.vpc_id
  db_subnet_ids   = module.vpc.private_db_subnet_ids
  security_group_ids = [module.security_groups.aurora_sg_id]
  kms_key_arn     = module.kms.aurora_key_arn
  enhanced_monitoring_role_arn = module.iam.aurora_monitoring_role_arn
  
  engine_version           = "16.4"
  instance_class           = "db.r6g.large"
  instance_count           = 2
  backup_retention_period  = 35
  backup_window            = "10:00-11:00"  # JST 19:00-20:00
  maintenance_window       = "sun:18:00-sun:19:00"  # JST sun:03:00-sun:04:00
  deletion_protection      = true
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  enhanced_monitoring_interval = 60
}
```

---

## 7. 静的解析 (CI で必須)

### 7.1 必須ツール

| ツール | 目的 |
|---|---|
| `terraform fmt` | フォーマット |
| `terraform validate` | 構文検証 |
| `tflint` | Lint (AWS specific rules) |
| `tfsec` | セキュリティ scanner |
| `Checkov` | ポリシー違反検知 |
| `terraform-docs` | README 自動生成 |

### 7.2 ローカル実行

```bash
# fmt
terraform fmt -recursive

# validate
terraform init -backend=false
terraform validate

# tflint
tflint --init
tflint --recursive

# tfsec
tfsec --soft-fail-warnings .

# Checkov
checkov -d .
```

### 7.3 重大指摘の扱い
- High / Critical 指摘: 修正必須 (CI ブロック)
- Medium 指摘: PR レビューで議論
- Low 指摘: 適時対応

---

## 8. 危険な操作の禁止

### 8.1 禁止コマンド (本番)
- `terraform destroy` (PROD)
- `terraform state rm` (PROD、State 不整合化)
- `terraform import` (PROD、要レビュー)
- `terraform apply -target=...` (PROD、State 不整合化)

### 8.2 deny ポリシー (Claude Code / CC permissions)
- `terraform apply` / `destroy` / `aws delete*` / `aws terminate*` は permissions.deny
- 詳細: CLAUDE.md ルール (AWS / IaC 案件専用ルール)

---

## 9. apply 承認ゲート

| 環境 | 承認者 | 承認方法 |
|---|---|---|
| MUT | 不要 | 自動 apply |
| LT | 不要 | 自動 apply (要件次第) |
| ST | PM (1 名) | GitHub Environment Required reviewer |
| DEV-IT | PM (1 名) | 同上 |
| PROD | PM + IaC リード (2 名) | 同上 |

詳細は [40-3_CI-CDパイプライン定義](40-3_CI-CDパイプライン定義.md) 参照。

---

## 10. 監査エビデンス取得

### 10.1 apply ログ
- CI/CD ログ (GitHub Actions / GitLab CI 等) を S3 にアーカイブ
- 保管期間: 365 日
- PR との紐付け必須

### 10.2 Drift Detection
- 週次で `terraform plan` を CI で実行
- 差分があれば通知 (手動変更検知)

---

## 11. モジュールバージョン管理

### 11.1 リポジトリ構成
- モジュールは GitHub (or GitLab) Tag で管理 (`v1.0.0`)
- environments からは tag を参照

```hcl
module "aurora" {
  source = "git::https://github.com/{org}/coupon-terraform-modules.git//aurora?ref=v1.0.0"
  # ...
}
```

### 11.2 アップデートフロー
1. モジュール変更 → PR
2. MUT / LT で動作確認
3. Tag 作成 (v1.X.Y)
4. environments の参照を順次更新 (LT → ST → DEV-IT → PROD)

---

## 12. ハルシネーション防止ルール (Codex レビュー対応)

### 12.1 必須事項
- リソース属性名は必ず HashiCorp 公式 Provider Docs で確認 (terraform-mcp-server / Registry)
- AWS 公式仕様は AWS Knowledge MCP / docs.aws.amazon.com で裏取り
- 未確認の挙動は「(要確認)」「(PoC 必要)」と明示

### 12.2 禁止事項
- 想像で属性名・引数を書く
- 古いバージョンの記述を引用する (Provider バージョン明示なし)
- AWS Console UI の動きで Terraform 仕様を推測する

---

## 13. Exit Criteria

- [ ] 全モジュール完成
- [ ] 環境別 main.tf 完成
- [ ] CI 静的解析全パス (重大指摘 0)
- [ ] State Backend 設定済
- [ ] モジュール README 整備
- [ ] Drift Detection ジョブ稼働

---

## 14. 出典

- HashiCorp Terraform https://developer.hashicorp.com/terraform/docs
- AWS Provider https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- AWS Provider rds_cluster https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
- tflint https://github.com/terraform-linters/tflint
- tfsec https://github.com/aquasecurity/tfsec
- Checkov https://github.com/bridgecrewio/checkov
- AWS Naming / Tagging Best Practices https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html
