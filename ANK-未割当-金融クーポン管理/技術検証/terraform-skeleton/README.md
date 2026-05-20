# Terraform Skeleton — Coupon Management System

**目的**: 本案件 (金融クーポン管理) で利用する AWS リソースの Terraform モジュール骨格。**FISC 第11版 / AWS WA FSI Lens / 金融庁 サイバーセキュリティGL / PCI-DSS v4.0 / NIST 800-53 r5 を意識した security baseline 込み**。

> 適合性マトリクスは **[COMPLIANCE.md](./COMPLIANCE.md)** を参照。

## 前提

- Terraform: ~> 1.10
- AWS Provider: hashicorp/aws ~> 5.100
- リージョン: ap-northeast-1 (Primary), ap-northeast-3 (DR、要協議)

## ディレクトリ構成

```
terraform-skeleton/
├── modules/                # 再利用モジュール
│   ├── vpc/                # VPC / Subnet / Route Table / Flow Logs
│   ├── ecs/                # ECS Cluster / Service / Task Definition
│   ├── aurora/             # Aurora PostgreSQL + pgAudit + Activity Streams
│   ├── s3/                 # S3 + Object Lock COMPLIANCE + ssl_only policy
│   ├── iam/                # IAM Role / Policy / OIDC / Permissions Boundary
│   ├── route53/            # Hosted Zone / Record
│   ├── monitoring/         # CloudWatch Alarm / SNS / Cost Anomaly Detection
│   ├── security_baseline/  # GuardDuty / Security Hub / Config / Macie / Inspector / IAM Access Analyzer  ★ FISC/PCI
│   ├── cloudtrail/         # Multi-region trail + log file integrity + CloudTrail Lake               ★ FISC/PCI
│   ├── vpc_endpoints/      # PrivateLink (S3/DynamoDB/KMS/SecretsManager/STS/Logs/ECR/SSM)            ★ FSI Lens
│   ├── backup/             # AWS Backup + Vault Lock + cross-region copy                              ★ FISC
│   └── waf/                # WAFv2 (Managed Rules + rate limit + geo block + logging)                 ★ PCI-DSS Req6.4
├── environments/           # 環境別構成
│   └── prod/
├── COMPLIANCE.md           # FISC / FSI Lens / PCI / NIST 適合マトリクス
└── README.md (本ファイル)
```

## 各モジュールの責務

| Module | 責務 | 主要リソース | 規制対応 |
|---|---|---|---|
| vpc | VPC / Subnet / Route Table / NAT GW (オプション) / Flow Logs | aws_vpc, aws_subnet, aws_flow_log | FISC 6.2 |
| ecs | ECS Cluster / Service / Task Definition | aws_ecs_cluster, aws_ecs_service | - |
| aurora | Aurora PostgreSQL + pgAudit + Activity Streams | aws_rds_cluster, aws_rds_cluster_activity_stream | **FISC 4.5 / PCI Req10** |
| s3 | S3 Bucket / Versioning / Object Lock COMPLIANCE / Lifecycle / ssl_only | aws_s3_bucket_*, aws_s3_bucket_policy | **FISC / e-文書法 / PCI Req4** |
| iam | IAM Role / Policy / OIDC Provider / Permissions Boundary | aws_iam_role, aws_iam_policy | **FSI Lens / FISC 6.5** |
| route53 | Hosted Zone / Record | aws_route53_zone, aws_route53_record | - |
| monitoring | CloudWatch Alarm / SNS Topic / Cost Anomaly Detection + topic policy | aws_cloudwatch_metric_alarm, aws_sns_topic, aws_ce_anomaly_subscription | FSI Lens Cost |
| **security_baseline** | GuardDuty / Security Hub / Config / Macie / Inspector v2 / IAM Access Analyzer | aws_guardduty_detector, aws_securityhub_*, aws_config_*, aws_macie2_*, aws_inspector2_enabler, aws_accessanalyzer_analyzer | **FISC / 金融庁GL / PCI / NIST** |
| **cloudtrail** | Multi-region trail + log file integrity validation + CloudTrail Lake | aws_cloudtrail, aws_cloudtrail_event_data_store, aws_cloudwatch_log_group | **FISC 4.5 / PCI Req10** |
| **vpc_endpoints** | AWS PrivateLink (S3/DynamoDB/KMS/SecretsManager/STS/Logs/ECR/SSM/...) | aws_vpc_endpoint, aws_security_group | **FSI Lens SbD / FISC 6.2** |
| **backup** | AWS Backup vault + plan + selection + Vault Lock + cross-region copy | aws_backup_vault, aws_backup_plan, aws_backup_vault_lock_configuration | **FISC 5.1 / e-文書法** |
| **waf** | WAFv2 Web ACL (Managed Rules + rate limit + geo block) + logging | aws_wafv2_web_acl, aws_wafv2_web_acl_association, aws_wafv2_web_acl_logging_configuration | **PCI Req6.4 / 金融庁GL** |

## 利用方法

### 環境別 apply

```bash
cd ANK-未割当-金融クーポン管理/技術検証/terraform-skeleton/environments/mut
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### CI/CD (GitHub Actions)

ワークフローは **mono-repo (`mattyopon/Business`) のルート `.github/workflows/coupon-terraform-*.yml`** に配置している
(GitHub Actions はリポジトリルートの `.github/workflows/` しか検出しないため)。
`env.TF_BASE: ANK-未割当-金融クーポン管理/技術検証/terraform-skeleton` で本ディレクトリを参照する。

`paths` フィルタは `ANK-未割当-金融クーポン管理/技術検証/terraform-skeleton/**` でスコープしているので、
他案件ディレクトリへのコミットでは起動しない。

`secrets.AWS_ACCOUNT_COUPON_<env>` 命名で本案件専用の AWS account ID を mono-repo 全体で衝突しないよう分離している。

必須 secret 一覧:

| Secret 名 | 用途 |
|---|---|
| `AWS_ACCOUNT_COUPON_<env>` | OIDC AssumeRole 対象アカウント ID |
| `IAM_PERMISSIONS_BOUNDARY_ARN_COUPON_<env>` | 環境別 IAM Permissions Boundary ARN。PF 提供 or iam モジュール作成の cicd_apply_boundary ARN を指す。未設定だと apply は IAM Deny で失敗する |
| `COUPON_TFVARS_<env>` | 環境別 `terraform.tfvars` の HCL 全文 (multi-line secret)。`terraform.tfvars.example` を雛形に、cost_center / vpc_cidr / KMS ARN / SG ID 等を全て埋めて投入する。**シークレット値 (KMS ARN 等) を含むため必ず secret 経由、コミット禁止** |
| `SLACK_WEBHOOK_OPS` | Slack 通知 webhook URL |

### モジュール参照例

```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  prefix   = "coupon-mut"
  vpc_cidr = "10.0.0.0/20"
  az_count = 2
}
```

## 静的解析

```bash
terraform fmt -recursive
terraform validate
tflint --recursive
tfsec .
checkov -d .
```

## 注意

- **本スケルトンは骨格のみ**。詳細設計フェーズで各モジュールを完成させる。
- KMS Key / Identity Center / セキュリティサービス (GuardDuty 等) は **PF 側集中管理を想定** しているため、本スケルトンには含まない (PF 側ガイドライン受領後に調整)。
- Aurora の暗号化は **作成時固定**。設計時に KMS CMK 利用を確定すること。

## 出典

- HashiCorp Terraform https://developer.hashicorp.com/terraform/docs
- AWS Provider https://registry.terraform.io/providers/hashicorp/aws/latest/docs
