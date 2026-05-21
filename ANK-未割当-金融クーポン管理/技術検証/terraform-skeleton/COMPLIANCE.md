# 金融系セキュリティ・監査要件 適合性マトリクス

本ドキュメントは `terraform-skeleton` が **FISC 安全対策基準 第11版 (2023-03)** / **AWS Well-Architected FSI Lens for FISC (2026-01-27)** / **金融庁「金融分野におけるサイバーセキュリティに関するガイドライン」(2024-10-04 公表、2025-12-08 改正案)** / **PCI-DSS v4.0** / **NIST SP 800-53 r5** の要件にどう対応しているかをまとめたマトリクス。

> **辛口注記**: 「FISC 第11版で要求される 318 項目すべてに対応」とは主張しない。本スケルトンが提供するのは **基盤の足場のみ**。プロジェクト固有のリスクアセスメント・運用ルール・教育・BCM 演習等の組織的対応は別途必要。

## 全体方針: AWS WA FSI Lens 4 設計原則 (2026-01-27 publication)

| # | 原則 | 本リポジトリでの実装 |
|---|------|---------------------|
| 1 | Documented operational planning (Three Lines of Defense) | README に役割分担明文化 (1st line=開発 / 2nd=コンプライアンス・リスク / 3rd=内部監査)。GitHub Environment 承認者を PROD で 2 名以上 |
| 2 | Automated infrastructure and application deployment | Terraform + GitHub Actions (OIDC, plan/apply/drift workflows)、Hooks で fmt/validate 強制 |
| 3 | Security by Design | KMS CMK / S3 Object Lock / S3 TLS-only / IAM Permissions Boundary / pgAudit / Activity Streams / VPC Endpoint / WAF / Macie |
| 4 | Automated governance | AWS Config + Conformance Pack / Security Hub CSPM / IAM Access Analyzer / Cost Anomaly Detection / Tag Policy (PF想定) |

## サービス別マッピング

凡例: ✅ 既存対応 / ⚙ 本 PR で追加 / ⚠ PF (集中管理) 想定 / 🔜 別 PR 予定 / ❌ 未対応

### A. データ保護 (Security by Design)

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| KMS CMK 暗号化 (Aurora / S3 / SNS / Secrets / Logs) | FSI Lens SbD / FISC 4.4 | ✅ | `modules/aurora` `kms_key_id`、`modules/s3` `aws_s3_bucket_server_side_encryption_configuration`、`modules/monitoring` `kms_master_key_id` |
| TLS 強制 (S3) | PCI-DSS Req4.1 / FSI Lens | ✅ | `modules/s3` `aws_s3_bucket_policy.ssl_only` (DenyInsecureConnections) |
| TLS 強制 (Aurora) | PCI-DSS Req4.1 | ✅ | `modules/aurora` parameter `rds.force_ssl=1` |
| pgAudit (SQL 監査) | FISC 第11版 4.5 / PCI Req10 | ⚙ | `modules/aurora` `shared_preload_libraries=pgaudit` + `pgaudit.log=ddl,write,role` |
| RDS Activity Streams (改竄不能監査) | PCI Req10.5 / FISC 4.5 | ⚙ | `modules/aurora` `aws_rds_cluster_activity_stream`、sync mode |
| Performance Insights | FSI Lens Performance | ✅ | `modules/aurora` `performance_insights_enabled=true` |
| S3 Object Lock COMPLIANCE 7年 | FISC / 金融商品取引法 / e-文書法 | ✅ | `modules/s3` audit-logs bucket `object_lock_mode=COMPLIANCE, object_lock_days=2557` |
| Secrets Manager + auto rotation | NIST IA-5 / PCI Req8.3 | ✅ (作成) / 🔜 (rotation Lambda) | `modules/aurora` `manage_master_user_password=true` |
| Macie (PII 自動検出) | 個人情報保護法 / FISC | ⚙ | `modules/security_baseline` `aws_macie2_account` + `aws_macie2_classification_job` |

### B. 監査ログ / 証跡 (Audit Trail)

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| CloudTrail multi-region + log file integrity | FISC 4.5 / PCI Req10 / 金融庁GL | ⚙ | `modules/cloudtrail` `is_multi_region_trail=true, enable_log_file_validation=true` |
| CloudTrail organization trail | FSI Lens | ⚙ | `modules/cloudtrail` `is_organization_trail` (PF が delegated admin) |
| CloudTrail Lake (90日超 SQL 検索) | PCI Req10.5.2 | ⚙ | `modules/cloudtrail` `aws_cloudtrail_event_data_store` 7年保管 |
| VPC Flow Logs | FISC 6.2 / PCI Req10.3 | ✅ (CWLog) / 🔜 (S3+Athena) | `modules/vpc` `aws_flow_log` |
| AWS Config 全リソース記録 | FSI Lens Operational / FISC 8.4 | ⚙ | `modules/security_baseline` `aws_config_configuration_recorder` (all_supported=true) |
| Config Conformance Pack (PCI/NIST/FISC) | PCI 補完 / FISC | 🔜 | `modules/security_baseline` で別途 conformance pack 投入想定 |
| ALB Access Log → S3 | PCI Req10.3 | 🔜 | `modules/ecs` または別 alb モジュールで対応 |
| WAF Log → CWLog/S3 | PCI Req10.3 / 金融庁GL 攻撃検知 | ⚙ | `modules/waf` `aws_wafv2_web_acl_logging_configuration` |

### C. セキュリティ検知・モニタリング

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| GuardDuty | FSI Lens / 金融庁GL 攻撃検知 | ⚙ | `modules/security_baseline` `aws_guardduty_detector` + S3/EKS/Malware datasource |
| Security Hub (FSBP/PCI/CIS) | PCI / FSI Lens | ⚙ | `modules/security_baseline` `aws_securityhub_standards_subscription` |
| AWS Config Rules / CSPM | FSI Lens / FISC | ⚙ | `modules/security_baseline` (Config Recorder) + Security Hub standards (内包) |
| Inspector v2 (ECR/EC2/Lambda) | NIST SI-2 / 金融庁GL | ⚙ | `modules/security_baseline` `aws_inspector2_enabler` |
| Macie (S3 PII) | 個人情報保護法 / FISC | ⚙ | `modules/security_baseline` `aws_macie2_account` |
| IAM Access Analyzer (外部公開) | FSI Lens Security | ⚙ | `modules/security_baseline` `aws_accessanalyzer_analyzer` (external_access + unused_access) |
| AWS Audit Manager (PCI v4 / NIST) | PCI 4.0 自動 evidence collection | ⚙ | `modules/audit_manager` `aws_auditmanager_account_registration` + standard framework data source (PCI / NIST 800-53) + `aws_auditmanager_assessment` × 2 |

### D. ID & アクセス

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| IAM Identity Center (SSO) | FSI Lens / FISC 6.5 | ⚠ | PF 側で集中管理想定。本モジュールではフェデレーション ARN を変数で受け取る |
| Permissions Boundary | FSI Lens / FISC 6.5 | ✅ | `modules/iam` `aws_iam_policy.cicd_apply_boundary` を全 IAM Role に付与 |
| 静的 Key 禁止 / OIDC 化 | PCI Req8.6 / FSI Lens | ✅ | GitHub Actions OIDC (`aws-actions/configure-aws-credentials`) |
| MFA enforcement | PCI Req8.4 | ⚠ | IAM Identity Center 側で組織ポリシー強制 |
| Root account 防御 | PCI Req2 / FISC 6.5 | ⚠ | Org 側 SCP で root 操作遮断、Hardware MFA |
| Least privilege apply role | FSI Lens / FISC | ✅ (loop 1-12 で改善) | `modules/iam` `cicd_apply_min` scoped allow + RequireBoundary Deny |

### E. ネットワーク

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| Multi-AZ VPC (3 AZ) | FSI Lens Reliability / FISC 5.1 | ✅ | `modules/vpc` `az_count=3` |
| Subnet Tier 分離 (public/private/isolated) | FSI Lens / PCI Req1.3 | ✅ | `modules/vpc` `create_isolated_batch_subnet=true` |
| VPC Endpoint (PrivateLink) | FSI Lens SbD / FISC 6.2 | ⚙ | `modules/vpc_endpoints` (S3/DynamoDB gateway + 13 interface) |
| Security Group + NACL 二重 | PCI Req1.2 | ✅ (SG) / 🔜 (NACL) | `modules/vpc` で NACL 追加検討 |
| WAF (ALB) | PCI Req6.4 / 金融庁GL | ⚙ | `modules/waf` Managed rule + rate limit + geo block |
| Shield Advanced | DDoS 対策 | 🔜 | 必要時に env 側で `aws_shield_protection` 追加 (有償) |
| Network Firewall (Egress 検査) | FSI Lens SbD | ⚠ | PF 集中想定 (TGW 経由 Egress Inspection VPC) |
| TGW / Direct Connect | FSI Lens | ⚠ | PF 集中想定 |

### F. 回復性 / DR

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| Multi-AZ Aurora | FSI Lens Reliability | ✅ | `modules/aurora` `instance_count=2` |
| Aurora Global Database (cross-region) | FSI Lens Reliability / FISC 5.1 | ⚙ | `modules/aurora` `aws_rds_global_cluster` (enable_global_database=true で有効化、primary 側 attach。secondary cluster は env 側で provider alias 経由) |
| AWS Backup (cross-region copy) | FSI Lens / FISC 5.1 | ⚙ | `modules/backup` `aws_backup_plan` + `copy_action` |
| AWS Backup Vault Lock COMPLIANCE | FISC / e-文書法 | ⚙ | `modules/backup` `aws_backup_vault_lock_configuration` |
| S3 Cross-Region Replication | FISC 5.1 / 監査記録 BCP | 🔜 | `modules/s3` で audit-logs バケット の `aws_s3_bucket_replication_configuration` 追加 |
| Route53 Failover Routing | FSI Lens | 🔜 | `modules/route53` で failover record 追加 |
| AWS Resilience Hub (RTO/RPO 検証) | FSI Lens Reliability | 🔜 | 別 PR |

### G. 運用 / ガバナンス (Three Lines of Defense)

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| AWS Organizations + SCP | FSI Lens / FISC 8.4 | ⚠ | PF 集中想定 (Region 制限 / 危険 API ブロック) |
| AWS Control Tower (Landing Zone) | FSI Lens | ⚠ | PF 集中想定 |
| Change Calendar (SSM) | FISC 5.2 / 金融庁GL 変更管理 | ✅ | `.github/workflows/coupon-terraform-apply.yml` `check-change-calendar` job |
| Patch Manager + Compliance | NIST SI-2 / FISC 4.7 | 🔜 | 別 PR (EC2/ECS task definition 側) |
| Cost Anomaly Detection | FSI Lens Cost | ✅ | `modules/monitoring` `aws_ce_anomaly_subscription` + `aws_sns_topic_policy.cost_anomaly` |
| Tag Policy 強制 | FSI Lens / FISC 8.3 | ⚠ | PF 側 Org tag-policy 想定 |
| default_tags 厳格 | FSI Lens Cost / 監査 | ✅ | `environments/prod/main.tf` `provider.default_tags` |

### H. インシデント対応

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| Slack 通知 (P1/P2/Security/Cost) | 金融庁GL 報告体制 | ✅ | `modules/monitoring` SNS Topic 4分類 |
| GuardDuty findings → EventBridge | FSI Lens / 金融庁GL | 🔜 | 別 PR で EventBridge rule + Lambda 自動隔離追加 |
| AWS Incident Manager | NIST IR / FISC | 🔜 | 運用設計確定後 |
| BCM / DR 演習 | FSI Lens / FISC 5.1 | ⚠ | 組織運用 (本リポジトリ範囲外) |

### I. CI/CD ガバナンス

| 要件 | 出典 | 対応状況 | モジュール / 設定 |
|---|---|---|---|
| IAM OIDC for GitHub Actions | FSI Lens / PCI Req8.6 | ✅ | `modules/iam` `aws_iam_openid_connect_provider.github` |
| Least privilege apply role | FSI Lens | ✅ (loop 1-12) | `modules/iam` `cicd_apply_min` |
| Drift detection | FISC 8.4 / FSI Lens | ✅ | `.github/workflows/coupon-terraform-drift.yml` 週次 |
| SAST/SCA (Checkov/tfsec/tflint) | PCI Req6 / FSI Lens | ✅ | `coupon-terraform-plan.yml` で実行 |
| Branch protection / required reviewers | FSI Lens / 金融庁GL | ⚠ | GitHub Repo 設定 (PF 標準想定) |
| Signed commits | NIST CM-5 | 🔜 | git config + gpg/Sigstore 検討 |

## 「未対応 / 別 PR」リスト (Issue 化推奨)

優先度順:

1. ~~**[P1] AWS Audit Manager assessment**~~ → ✅ **対応済 (PR #10)**: `modules/audit_manager` で account_registration + PCI/NIST 標準 framework の data source 参照 + assessment + process owner role
2. ~~**[P1] Aurora Global Database (cross-region)**~~ → ✅ **対応済 (PR #10)**: `modules/aurora` に `aws_rds_global_cluster` を追加、`enable_global_database=true` で primary cluster を global に attach。secondary region cluster は env 側で別 provider alias で定義
3. **🔜 [P2] S3 Cross-Region Replication for audit-logs** — `aws_s3_bucket_replication_configuration` で ap-northeast-3 に複製
4. **🔜 [P2] AWS Config Conformance Pack (PCI/NIST/HIPAA/CIS)** — `aws_config_conformance_pack` で複数 pack 投入
5. **🔜 [P2] ALB Access Log → S3** — ECS module または alb module で `access_logs` 設定
6. **🔜 [P2] EventBridge rule for GuardDuty findings → Lambda 自動隔離** — 重大度 8+ で自動 SG isolation
7. **🔜 [P2] Secrets Manager auto-rotation Lambda** — RDS master password rotation
8. **🔜 [P3] Route53 Failover routing** — DR site 用
9. **🔜 [P3] VPC NACL stateless 二重防御** — SG だけでなく NACL でも禁止ポート明示
10. **🔜 [P3] AWS Resilience Hub assessment** — RTO/RPO validation
11. **🔜 [P3] Signed commits (Sigstore / gpg)** — 改竄防止
12. **🔜 [P3] Patch Manager + Compliance reporting** — EC2/ECS Fargate Platform Version pinning

## 適合可否の最終判定

| フレームワーク | スケルトン段階の適合性 | 商用稼働までに必須の上乗せ |
|---|---|---|
| FISC 第11版 (クラウド利用) | **基盤レベルで対応**。318項目中、技術基準 (~150項目) のうち AWS マネージドで吸収できる項目は概ねカバー | 運用基準 / 監査基準は組織運用で対応 (規程整備・教育・演習) |
| 金融庁 サイバーセキュリティGL 176項目 | **基本的対応事項の技術的部分はカバー** | リスクアセスメント・経営層関与・3rd party リスク管理は組織的対応 |
| AWS WA FSI Lens | 4 設計原則のうち 1, 2, 3 はカバー。4 (Automated governance) は本 PR で AWS Config / Security Hub 追加で前進 | Control Tower / Account Factory 等の Org レベル統制は PF 側 |
| PCI-DSS v4.0 | クーポンが PAN を扱う場合、Req1/2/3/4/6/7/8/10 の技術要件はかなりカバー | Req9 (物理) は AWS の責任共有モデルで吸収、Req11 (テスト) / Req12 (ポリシー) は組織対応 |
| NIST 800-53 r5 (中程度ベースライン) | Security Hub の NIST standard で継続検証可能 | 高ベースラインは追加コントロール必要 |

## 出典

1. FISC「金融機関等コンピュータシステムの安全対策基準・解説書（第11版）」(2023-03)
2. AWS「金融機関向け AWS FISC 安全対策基準対応リファレンス」(2023-07)
3. AWS Well-Architected Framework FSI Lens (Publication 2026-01-27, https://docs.aws.amazon.com/wellarchitected/latest/financial-services-industry-lens/)
4. 金融庁「金融分野におけるサイバーセキュリティに関するガイドライン」(2024-10-04 公表 / 2025-12-08 改正案)
5. PCI Security Standards Council「PCI DSS v4.0」(2022, 移行期限 2025-03-31)
6. AWS BLEAFSI (Baseline Environment on AWS for Financial Services Institute) — https://github.com/aws-samples/baseline-environment-on-aws-for-financial-services-institute
7. NIST SP 800-53 Rev. 5 (2020-09 + 2023-12 update)
