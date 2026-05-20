# Terraform Skeleton — Coupon Management System

**目的**: 本案件で利用する AWS リソース (VPC / ECS / Aurora / S3 / IAM / Route 53 / CloudWatch) の Terraform モジュール骨格。詳細設計フェーズで各モジュールを完成させる前提のスケルトン。

## 前提

- Terraform: ~> 1.10
- AWS Provider: hashicorp/aws ~> 5.100
- リージョン: ap-northeast-1 (Primary), ap-northeast-3 (DR、要協議)

## ディレクトリ構成

```
terraform-skeleton/
├── modules/                # 再利用モジュール
│   ├── vpc/
│   ├── ecs/
│   ├── aurora/
│   ├── s3/
│   ├── iam/
│   ├── route53/
│   └── monitoring/
├── environments/           # 環境別構成
│   ├── mut/
│   ├── lt/
│   ├── st/
│   └── prod/
└── README.md (本ファイル)
```

## 各モジュールの責務

| Module | 責務 | 主要リソース |
|---|---|---|
| vpc | VPC / Subnet / Route Table / NAT GW (オプション) | aws_vpc, aws_subnet, aws_route_table |
| ecs | ECS Cluster / Service / Task Definition | aws_ecs_cluster, aws_ecs_service, aws_ecs_task_definition |
| aurora | Aurora PostgreSQL Cluster / Instance / Parameter Group | aws_rds_cluster, aws_rds_cluster_instance |
| s3 | S3 Bucket / Versioning / Object Lock / Lifecycle | aws_s3_bucket, aws_s3_bucket_versioning, etc. |
| iam | IAM Role / Policy / OIDC Provider | aws_iam_role, aws_iam_policy |
| route53 | Hosted Zone / Record | aws_route53_zone, aws_route53_record |
| monitoring | CloudWatch Alarm / Dashboard / Composite Alarm | aws_cloudwatch_metric_alarm |

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
