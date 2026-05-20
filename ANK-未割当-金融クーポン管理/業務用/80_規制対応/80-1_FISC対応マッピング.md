# 80-1. FISC 対応マッピング

**目的**: 「FISC 金融機関等コンピュータシステムの安全対策基準・解説書 (第 11 版、2023 年 3 月発行)」の各項目に対する本システムの対応をマッピングする。  
**運用**: 要件定義中に Draft 作成 → 基本設計で詳細化 → 構築時にエビデンス取得方法確定 → 結合試験中にエビデンス取得 → 監査時提示。  
**参考**: AWS 公式「金融機関向け AWS FISC 安全対策基準対応リファレンス 第 2 版」(2024 年 8 月公開、無償提供)。

---

## 1. FISC 第 11 版 の構成 (概要)

> 出典: FISC https://www.fisc.or.jp/publication/book/005831.php、AWS https://aws.amazon.com/jp/blogs/news/financereferencearchitecture-fisc11-update/

FISC 第 11 版は以下のカテゴリで構成される (詳細項目は購入書籍参照):

| 大分類 | 内容 |
|---|---|
| 統制基準 | 組織・体制・運用ルール |
| 実務基準 | 物理 / 論理 / 運用 / 開発 / 監査 |
| 設備基準 | 物理セキュリティ / DC |
| 技術基準 | ネットワーク / 暗号化 / 認証 / ログ |
| **クラウドサービス固有事項** | 第 11 版で追加・拡充。責任分界 / リファレンス・アーキ |

**注意**: FISC 第 11 版の項目は数百項目に及び、全項目を網羅するには書籍購入が必要。本書は AWS 公式リファレンスベースの **代表項目** マッピング。

---

## 2. 領域別 マッピング (代表項目)

### 2.1 統制 (組織・体制)

| 項目 (例) | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| 情報セキュリティポリシー策定 | 顧客側ポリシーに従う + 本案件ポリシー策定 | ポリシー文書 | (要記入) |
| セキュリティ責任者明確化 | PM + 顧客セキュリティ責任者 | 体制図 | (要記入) |
| 情報資産分類 | データ分類 (機密 / 機密性高 / 一般) | データ分類表 | (要記入) |
| インシデント対応体制 | Tier 1-3 体制 (運用設計 § 1) | 運用設計書 / Runbook | (要記入) |
| 監査体制 | 内部監査 + 外部監査 (年次) | 監査計画 | (要記入) |

### 2.2 物理セキュリティ (AWS の責任範囲)

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| データセンタ物理セキュリティ | AWS の責任範囲 (AWS Compliance Program) | AWS SOC 2 / ISO 27001 / PCI DSS 報告書 | (要 AWS 取得) |
| 環境制御 (空調・電源) | AWS の責任範囲 | AWS Compliance 報告書 | (要 AWS 取得) |
| 入退室管理 | AWS の責任範囲 | AWS Compliance 報告書 | (要 AWS 取得) |

> 出典: AWS Compliance https://aws.amazon.com/compliance/

### 2.3 論理アクセス制御

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| ユーザ ID 管理 | IAM Identity Center | Identity Center ログ (CloudTrail) | (要記入) |
| 認証強化 (MFA) | MFA 必須 | Identity Center 設定 | (要記入) |
| 権限分離 (Least Privilege) | Permission Set + IAM Policy | IAM Policy / Permission Set 設定 | (要記入) |
| 特権 ID 管理 | Break Glass Role (使用時のみ有効化) | Break Glass 使用ログ | (要記入) |
| アクセスログ取得 | CloudTrail (全 API) | CloudTrail Log (PF 集中) | (要記入) |
| 不正アクセス検知 | GuardDuty | GuardDuty Finding | (要記入) |
| 異常ログイン検知 | CloudTrail + EventBridge アラート | アラートログ | (要記入) |

### 2.4 暗号化

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| 保存データ暗号化 | KMS CMK (Aurora / S3 / EFS / Secrets / CW Logs) | Terraform コード + KMS 設定 | (要記入) |
| 転送データ暗号化 | TLS 1.2+ (ALB / Aurora / VPCE) | 設定確認 | (要記入) |
| 鍵管理 | KMS CMK + 年次ローテーション | KMS Key Policy / Rotation 設定 | (要記入) |
| 鍵削除制御 | 30 日待機期間 + 4-eyes 承認 | 削除手順書 | (要記入) |

### 2.5 監査ログ / 証跡

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| API 呼び出しログ | CloudTrail (PF 集中) | CloudTrail Log S3 | (要記入) |
| アプリ監査ログ | S3 (Object Lock COMPLIANCE 7 年) | S3 Log + Object Lock 設定 | (要記入) |
| 改ざん防止 | S3 Object Lock COMPLIANCE + KMS CMK | S3 設定 | (要記入) |
| 長期保管 | 7 年 (Glacier Deep Archive) | S3 Lifecycle 設定 | (要記入) |
| ログ検索 | CloudWatch Logs Insights + Athena | クエリ実行履歴 | (要記入) |

### 2.6 ネットワーク

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| ネットワーク分離 | VPC / Subnet / SG / NACL | Terraform コード + 構成図 | (要記入) |
| 外部接続制御 | PF 集中 NW Firewall + WAF | 設定 + Log | (要記入) |
| 通信暗号化 | TLS 1.2+ | (前述) | (要記入) |
| 不要ポート遮断 | SG で最小限のみ | SG 設定 | (要記入) |
| Internet 公開 | Public Subnet は ALB のみ | VPC / SG 設定 | (要記入) |

### 2.7 可用性 / DR

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| 冗長化 | Multi-AZ (ECS / Aurora / ALB) | 設定 + 構成図 | (要記入) |
| バックアップ | Aurora 自動 35 日 + AWS Backup + Cross-region | Backup Plan + 取得履歴 | (要記入) |
| DR サイト | 大阪リージョン (要協議) | 設定 + 構成図 | (要記入) |
| RPO / RTO | < 15 分 / < 4 時間 (要協議) | DR 訓練結果 | (要記入) |
| DR 訓練 | 年 1 回以上 | 訓練レポート | (要記入) |
| BCP | 顧客側 BCP に準拠 | BCP 文書 (顧客) | (要記入) |

### 2.8 開発 / 変更管理

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| IaC | Terraform | コード + Git 履歴 | (要記入) |
| 変更管理プロセス | CAB + Change Calendar | CAB 議事録 + Change Calendar | (要記入) |
| デプロイ承認 | 環境別人手承認 (PM + リード) | CI/CD 承認ログ | (要記入) |
| 静的解析 | tflint / tfsec / Checkov | CI 結果ログ | (要記入) |
| 動的解析 / 脆弱性スキャン | Inspector / Trivy / ZAP | スキャン結果 | (要記入) |
| ペネトレーションテスト | 外部委託 (Cutover 前) | レポート | (要記入) |

### 2.9 運用

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| 監視 | CloudWatch + (Splunk) | ダッシュボード + アラート設定 | (要記入) |
| インシデント対応 | Tier 1-3 + Runbook | Runbook + Postmortem | (要記入) |
| 障害復旧 | 自動 (Multi-AZ) + 手動 Runbook | 復旧手順書 | (要記入) |
| 容量管理 | Auto Scaling + Cost Anomaly | 設定 + 月次レポート | (要記入) |
| Configuration Management | AWS Config (PF 集中) | Config Rule 結果 | (要記入) |

### 2.10 クラウドサービス固有事項 (第 11 版で拡充)

| 項目 | 本案件の対応 | エビデンス | 状態 |
|---|---|---|---|
| 責任分界モデル | AWS Shared Responsibility Model に準拠 + PF / 案件責任分界 | 責任分界表 | (要記入) |
| クラウドサービス事業者の評価 | AWS の認証 (SOC 2, ISO 27001, PCI DSS 等) | AWS Compliance 報告書 | (要 AWS 取得) |
| データ移転先の管理 | Tokyo + Osaka リージョン (日本国内) | Terraform 設定 | (要記入) |
| サービス事業者のサポート体制 | AWS Enterprise Support (推奨) | サポート契約書 | (要記入) |
| クラウドサービスからの撤退計画 | ベンダーロックイン低減 + データエクスポート手順 | 撤退計画書 | (要記入) |
| マルチクラウドリスク管理 | (本案件は AWS 単独想定) | - | - |
| 生成 AI の安全な活用 | (本案件では生成 AI 利用なし、要確認) | - | (要協議) |

> AWS リファレンス第 2 版で第 11 版「クラウドサービス固有事項」に対応した記載が追加されている。

---

## 3. AWS Shared Responsibility Model

```
┌─────────────────────────────────────────┐
│  顧客責任 (アプリ / データ / 設定)        │   ← 本案件
│  - データ                                   │
│  - プラットフォーム / アプリ                │
│  - OS / NW / FW 設定                        │
│  - クライアント側暗号化 / IAM               │
├─────────────────────────────────────────┤
│  AWS 責任 (基盤)                            │   ← AWS
│  - リージョン / AZ / DC                     │
│  - ハードウェア / ネットワーク              │
│  - 仮想化基盤                              │
└─────────────────────────────────────────┘

PF 側責任 (本案件の親アーキ):
- AWS Organizations / Control Tower / LZA
- Identity Center
- 監視・ログ集約基盤
- セキュリティサービス (GuardDuty / Security Hub / Config)
- 共通 KMS (一部)
- TGW / NW Firewall

本案件責任:
- アプリケーション (ECS Task 内容)
- 案件側 IAM (Permission Set 内)
- アプリ監査ログ (S3 Object Lock)
- 案件側 KMS Key
- 案件側 VPC リソース (SG / Route Table 等)
```

> 出典: https://aws.amazon.com/compliance/shared-responsibility-model/

---

## 4. 監査エビデンス取得計画

詳細は [80-3_監査エビデンス一覧](80-3_監査エビデンス一覧.md) を参照。

### 4.1 取得タイミング
- 構築フェーズ: 各設定値の取得 (Terraform plan / apply ログ)
- UT / IT / ST フェーズ: テスト結果 + 静的解析レポート
- 結合試験フェーズ: 連携試験エビデンス
- 総合テストフェーズ: 業務シナリオエビデンス + DR 訓練結果
- 本番運用: 月次レポート + 年次監査エビデンス

### 4.2 保管
- S3 (Object Lock COMPLIANCE) に 7 年保管
- アクセス権限: 監査部門 + PM

---

## 5. AWS 公式リファレンス活用

### 5.1 AWS FISC リファレンス第 2 版
- 2024 年 8 月公開 (無償)
- FISC 第 11 版に対応
- 出典: https://aws.amazon.com/jp/blogs/news/financereferencearchitecture-fisc11-update/

### 5.2 利用方法
- 全項目を取り込み、本案件マッピングと並行
- 不明点は AWS Account Team / Solutions Architect に質問
- AWS Knowledge MCP Server で公式情報を確認

### 5.3 関連 AWS 公式資料
- 金融リファレンスアーキテクチャ日本版: https://aws.amazon.com/jp/blogs/news/financereferencearchitecture-fisc11-update/
- AWS Compliance プログラム: https://aws.amazon.com/compliance/
- AWS Artifact (Compliance レポート取得): https://aws.amazon.com/artifact/

---

## 6. 監査計画との連動

### 6.1 内部監査
- 月次: 顧客監査部門との同期会議
- 四半期: 主要項目レビュー
- 年次: 全項目フルレビュー

### 6.2 外部監査
- 案件側で対応する場合は別途計画
- 監査人質問対応マニュアル整備 (顧客監査部門と協議)

---

## 7. Exit Criteria

- [ ] 全 FISC 第 11 版項目への対応マッピング v1.0 完成
- [ ] 顧客監査部門承認
- [ ] AWS FISC リファレンス第 2 版との突合完了
- [ ] エビデンス取得方法確定
- [ ] 監査計画策定

---

## 8. 出典

- FISC 安全対策基準 第 11 版 (令和 5 年 3 月) https://www.fisc.or.jp/publication/book/005831.php
- AWS FISC 第 2 版 (2024-08) https://aws.amazon.com/jp/blogs/news/financereferencearchitecture-fisc11-update/
- AWS Compliance プログラム https://aws.amazon.com/compliance/
- AWS Artifact https://aws.amazon.com/artifact/
- AWS Shared Responsibility Model https://aws.amazon.com/compliance/shared-responsibility-model/
- AWS Well-Architected FSI Lens https://docs.aws.amazon.com/wellarchitected/latest/financial-services-industry-lens/
- 金融機関向け AWS FISC 第 9 版 Reference (PDF、参考) https://d1.awsstatic.com/whitepapers/compliance/JP_Whitepapers/AWS_FISC_Guidelines_9thEdition.pdf
