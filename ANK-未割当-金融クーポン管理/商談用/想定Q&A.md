# 想定 Q&A — 商談時の技術的深掘り質問への準備

**目的**: 商談で出る技術質問に裏取りなしで答えられないものは「持ち帰り」と明示する。ハルシネーション厳禁。

---

## 1. 自己紹介・経験

### Q1-1. 過去の金融案件での担当役割は?
**A**: 金融機関向け AWS 共通基盤の構築 / 運用案件で PM 兼 SA を経験。マルチアカウント基盤・FISC 対応・運用保守までの一気通貫担当。詳細は経歴書参照。

### Q1-2. AWS 認定は持っていますか?
**A**: (回答準備、保有認定を記入)。本案件参画前に Security Specialty 取得計画あり。

### Q1-3. Terraform は実務でどの程度使ってますか?
**A**: マルチアカウント基盤の IaC 化、CI/CD 統合 (GitHub Actions OIDC)、tflint/tfsec/Checkov の静的解析運用まで実施経験。

### Q1-4. FISC 対応経験は?
**A**: 前案件で FISC 第 11 版 / AWS FISC リファレンス第 2 版をベースに対応マッピング作成。監査部門とのレビュー経験あり。

---

## 2. 案件理解

### Q2-1. 本案件で最大のリスクは何だと思いますか?
**A**: PF 側 PoC 結果のタイミング遅延と、親システム I/F 仕様確定遅延の 2 点。要件定義の前提が動く可能性が高いため、Day-1 で両者と週次同期会議を設定し、ガイドライン受領 → 影響分析 → 顧客合意のサイクルを 2 週間で回す体制を構築する想定。

### Q2-2. PF 側 PoC ガイドライン待ちで案件停止しませんか?
**A**: 「待ち項目」と「先行可能項目」を毎週仕分けします。先行可能なものは業務要件 / 非機能要件 / FISC 対応マッピング / Terraform skeleton 等多数あり、PF 側待ちで停止することはありません。

### Q2-3. 4 名体制でフェーズ一気通貫は現実的ですか?
**A**: 体制計画 (PM-01 § 5) では時期別役割分担を組んでいます。構築〜結合フェーズ重複期 (2027/5-11) はピーク 4 名で対応、それ以外は 1-3 名で十分回せる計画です。

---

## 3. 技術深掘り

### Q3-1. ECS Fargate を選んだ理由は?
**A**: 案件規模に対し EKS は運用工数過剰、Lambda はバッチ長時間処理 (15 分超) に向きません。Fargate はサーバレスでスケーリング自動、Multi-AZ 配置容易、Container Insights で監視も標準。要件定義時点での妥当性は ADR-001 で記載しています。最終確定は PF 側ガイドラインで覆る可能性を含む前提です。

### Q3-2. Aurora と RDS の使い分けは?
**A**: 本案件は Multi-AZ 高可用性 + 高速 Failover + Backup 35 日が必要なため Aurora を選択。RDS MySQL でも Multi-AZ は可能ですが、Aurora は 6 コピー × 3 AZ で復旧時間が短く、Read Replica 拡張も容易。出典: AWS Aurora 公式ドキュメント。

### Q3-3. Aurora の暗号化は KMS CMK でないとダメですか?
**A**: KMS CMK 必須。理由は (1) FISC / 金融庁要件で顧客管理暗号化が原則、(2) Cross-region snapshot 共有が CMK でないと不可、(3) Aurora の暗号化は作成時固定なので後から変えられない (R-E01 リスク)。詳細は基本設計セキュリティ章。

### Q3-4. CI/CD ツールは何を使いますか?
**A**: PF 側ガイドライン (G-06) 受領後に確定です。要件定義中は Terraform local apply で先行し、ガイドライン受領後にパイプライン化する想定。GitHub Actions / GitLab CI / Jenkins / CodePipeline のいずれも対応可能です。OIDC 連携でアクセスキー不要にします。

### Q3-5. Change Calendar の使い方は?
**A**: 4 つのカレンダー (deploy-calendar, freeze-yearend, freeze-monthend, freeze-campaign) を AND 評価。CI/CD パイプラインの apply 前に `aws ssm get-calendar-state` で OPEN/CLOSED を判定し、CLOSED ならブロック。緊急時は CIO 承認で Override。詳細は 40-4 設計書。

### Q3-6. 監視は CloudWatch だけで足りますか?
**A**: 基盤監視は CloudWatch、横断検索は Splunk (既存 SOC 想定) との連携を検討。FireLens (Fluent Bit) でログを CloudWatch Logs + Splunk HEC へ送信。要件は IT 統括と協議。

### Q3-7. ペネトレーションテストは必須ですか?
**A**: FISC / 金融庁の監査要件として強く推奨です。AWS Pen Test ポリシーに準拠し、ST 環境で外部委託で実施想定。Cutover 前に完了。

### Q3-8. Aurora の RPO / RTO は?
**A**: 目標は RPO < 15 分、RTO < 4 時間 (要協議)。Cross-region Backup (大阪) + Route 53 Failover で実現。Aurora Global Database を採用すれば RPO 数秒も可能ですがコスト高。要件次第。

### Q3-9. 監査ログの保管期間は?
**A**: FISC / 金融庁要件で 7 年保管想定。S3 Object Lock COMPLIANCE モード (改ざん不可) + Glacier Deep Archive で長期保管。詳細は 80-3 監査エビデンス一覧。

### Q3-10. PCI DSS 対応は必要ですか?
**A**: 本案件はカード会員データを扱わない設計 (顧客 ID のみ保持、決済は勘定系) です。Out of Scope の方向で要件定義時に確定予定。確定後にエビデンス取得。

---

## 4. プロジェクトマネジメント

### Q4-1. PF 側 / 親システム側との調整はどう進めますか?
**A**: 週次同期会議 (PF 側 60 分、親システム側 60 分) を Day-1 で設定。アジェンダ + 議事録 + Decision Log で書面化。責任分界を毎回確認します。

### Q4-2. 顧客監査部門との関係構築は?
**A**: 要件定義中の Day-30 までに月次同期会議を開始。FISC 対応マッピングを Day-30 時点で Draft 提示し、突然のレビュー要求を避けます。

### Q4-3. 要員不足リスクへの対策は?
**A**: 構築 + 結合フェーズ重複期は補強要員調達リードタイム (BP 1-2 ヶ月、自社 2-4 週間) を考慮し、2 ヶ月前から要請開始。自社マネージャ + 元請営業の 2 ルート確保。

### Q4-4. 自分の稼働超過リスクへの対策は?
**A**: 月稼働 180h 超で SA 補強要請、200h 超は過負荷ゲート Red (D1 § 6.1 ベース)。プレイヤー業務は SA / IaC リードに委譲。火曜・木曜 AM は PM 業務専用ブロック。

### Q4-5. スコープクリープへの対策は?
**A**: Day-1 で変更管理プロセスを顧客と合意。Change Request フォーム必須、CAB 経由。要件 Must/Should/Could 分類で優先度可視化。

---

## 5. 商務・契約

### Q5-1. 契約形態は何想定ですか?
**A**: 元請 SIer 経由の BP 要員 (SES の準委任契約想定)。詳細は元請 PL と確認。

### Q5-2. 稼働上限は?
**A**: 月 160h 標準 / 200h 上限想定。超過時は事前に元請 PL と協議。

### Q5-3. 契約更新の見込みは?
**A**: 構築フェーズ 22 ヶ月の契約後、Hyper Care + 運用保守の継続可能性。詳細は元請と協議。

### Q5-4. 顧客との直接交渉は?
**A**: BP 立場では元請経由が原則。技術詳細・Q&A は直接連携可、商務・契約・予算は元請同席必須、緊急対応は事後報告。

---

## 6. 持ち帰り対応の方針

### 不明回答の対応
- 「申し訳ありません、持ち帰り確認します」
- AWS Knowledge MCP / AWS 公式ドキュメントで裏取り
- 24h 以内に回答

### 嘘禁止
- 「たぶんこう」「確か」は回答しない
- 推測ベースで答えない
- 確認後の回答は出典 URL を必ず添付

---

## 7. 出典

- AWS 公式ドキュメント https://docs.aws.amazon.com/
- AWS FISC リファレンス第 2 版 https://aws.amazon.com/jp/blogs/news/financereferencearchitecture-fisc11-update/
- AWS Pen Test ポリシー https://aws.amazon.com/security/penetration-testing/
- AWS Aurora 公式 https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/
