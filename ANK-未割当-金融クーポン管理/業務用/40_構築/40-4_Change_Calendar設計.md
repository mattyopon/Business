# 40-4. AWS Systems Manager Change Calendar 設計

**目的**: 本案件で利用する Change Calendar の構成・運用・CI/CD 連携を定義する。  
**前提**: PF 側 Change Calendar ガイドライン (G-07) と整合させる。

---

## 1. Change Calendar とは

- AWS Systems Manager の機能
- カレンダーが OPEN / CLOSED 状態を持ち、変更可能期間を管理
- iCalendar (.ics) ファイル import 対応
- `aws ssm get-calendar-state` API で状態取得 (CI/CD 連携に利用)
- AND 条件で複数カレンダーを組合せ可能

出典: https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/systems-manager-change-calendar.html

---

## 2. 本案件のカレンダー構成

### 2.1 カレンダー一覧

| カレンダー名 | Default | 用途 | 評価方法 |
|---|---|---|---|
| coupon-prod-deploy-calendar | DEFAULT_CLOSED | 本番デプロイ可能期間 | 単独 OPEN なら apply 可 |
| coupon-freeze-yearend | DEFAULT_OPEN | 年末年始凍結 (12/29-1/4) | CLOSED イベント |
| coupon-freeze-monthend | DEFAULT_OPEN | 月末月初凍結 (顧客指定) | CLOSED イベント |
| coupon-freeze-campaign | DEFAULT_OPEN | キャンペーン期間中凍結 | CLOSED イベント (動的追加) |
| coupon-prod-maintenance | DEFAULT_CLOSED | メンテナンス時間帯 (運用作業向け) | OPEN イベント |

### 2.2 デプロイ判定ロジック

**全カレンダーの AND 評価**:
```
deploy_allowed =
  coupon-prod-deploy-calendar == OPEN
  AND coupon-freeze-yearend == OPEN
  AND coupon-freeze-monthend == OPEN
  AND coupon-freeze-campaign == OPEN
```

任意の 1 つが CLOSED なら apply 不可。

> AWS Change Calendar 公式の API `GetCalendarState` は複数カレンダーを引数に取り、いずれか CLOSED なら CLOSED を返す動作 (AND 評価)。

---

## 3. カレンダー定義 (Terraform)

### 3.1 coupon-prod-deploy-calendar (DEFAULT_CLOSED)

```hcl
resource "aws_ssm_document" "deploy_calendar" {
  name            = "coupon-prod-deploy-calendar"
  document_type   = "ChangeCalendar"
  document_format = "TEXT"
  
  attachments_source {
    key    = "SourceUrl"
    values = ["s3://coupon-prod-tf-state/change-calendar/deploy-calendar.ics"]
  }
  
  content = <<-EOF
    BEGIN:VCALENDAR
    PRODID:-//AWS//Change Calendar 1.0//EN
    VERSION:2.0
    X-CALENDAR-TYPE:DEFAULT_CLOSED
    X-WR-CALDESC:Coupon PROD Deploy Calendar
    BEGIN:VEVENT
    DTSTART:20270501T000000Z
    DTEND:20270501T235900Z
    SUMMARY:Initial Deploy Window
    UID:coupon-prod-initial-deploy
    END:VEVENT
    END:VCALENDAR
  EOF
  
  tags = {
    Purpose = "deploy-window-control"
  }
}
```

### 3.2 coupon-freeze-yearend (DEFAULT_OPEN with CLOSED 期間)

```hcl
resource "aws_ssm_document" "freeze_yearend" {
  name            = "coupon-freeze-yearend"
  document_type   = "ChangeCalendar"
  document_format = "TEXT"
  
  content = <<-EOF
    BEGIN:VCALENDAR
    PRODID:-//AWS//Change Calendar 1.0//EN
    VERSION:2.0
    X-CALENDAR-TYPE:DEFAULT_OPEN
    BEGIN:VEVENT
    DTSTART:20271229T150000Z
    DTEND:20280104T150000Z
    SUMMARY:Year-end freeze 2027-2028
    UID:coupon-freeze-yearend-2027-2028
    RRULE:FREQ=YEARLY
    END:VEVENT
    END:VCALENDAR
  EOF
}
```

> 時刻は UTC 必須。JST は +9h ずらして指定 (例: JST 0:00 = UTC -1d 15:00)。

### 3.3 coupon-freeze-monthend (DEFAULT_OPEN)

```hcl
resource "aws_ssm_document" "freeze_monthend" {
  name            = "coupon-freeze-monthend"
  document_type   = "ChangeCalendar"
  document_format = "TEXT"
  
  content = <<-EOF
    BEGIN:VCALENDAR
    PRODID:-//AWS//Change Calendar 1.0//EN
    VERSION:2.0
    X-CALENDAR-TYPE:DEFAULT_OPEN
    BEGIN:VEVENT
    DTSTART:20280131T150000Z
    DTEND:20280202T150000Z
    SUMMARY:Month-end freeze 2028-01
    UID:coupon-freeze-monthend-2028-01
    RRULE:FREQ=MONTHLY;BYMONTHDAY=-1
    END:VEVENT
    END:VCALENDAR
  EOF
}
```

> 顧客指定の月末月初凍結時間を確定後反映。

---

## 4. CI/CD 連携

### 4.1 apply 前チェック (GitHub Actions 例、ECMA Snake Case)

```yaml
- name: Check Change Calendar
  id: cal_check
  run: |
    set -e
    STATE=$(aws ssm get-calendar-state \
      --calendar-names \
        "arn:aws:ssm:ap-northeast-1::document/coupon-prod-deploy-calendar" \
        "arn:aws:ssm:ap-northeast-1::document/coupon-freeze-yearend" \
        "arn:aws:ssm:ap-northeast-1::document/coupon-freeze-monthend" \
        "arn:aws:ssm:ap-northeast-1::document/coupon-freeze-campaign" \
      --query 'State' --output text)
    
    NEXT_TRANSITION=$(aws ssm get-calendar-state \
      --calendar-names "arn:aws:ssm:ap-northeast-1::document/coupon-prod-deploy-calendar" \
      --query 'NextTransitionTime' --output text)
    
    echo "Calendar state: $STATE"
    echo "Next transition: $NEXT_TRANSITION"
    
    if [[ "$STATE" != "OPEN" ]]; then
      echo "::error::Deploy not allowed. Calendar is CLOSED."
      echo "::error::Next OPEN time: $NEXT_TRANSITION"
      exit 1
    fi
```

### 4.2 緊急変更時の Override
- CLOSED 期間中の緊急デプロイは `--ignore-calendar` フラグ (CI ワークフロー内で実装)
- 利用には CIO 承認 + 監査ログ取得必須

---

## 5. 運用ルール

### 5.1 カレンダー更新権限

| 権限 | 対象 | 承認者 |
|---|---|---|
| 通常イベント追加 (CLOSED 期間追加) | freeze-* | PM + 顧客主担当 |
| 緊急 OPEN | deploy-calendar | PM + IT 統括 |
| 凍結期間延長 | freeze-* | CIO 承認 |
| カレンダー新規作成 | 全カレンダー | PM + 監査部門 |

### 5.2 監査ログ
- 全カレンダー変更は CloudTrail で記録
- 月次レビュー (顧客監査部門と)

### 5.3 通知
- 凍結期間開始 24 時間前にチームに通知 (EventBridge → Slack)
- 凍結期間終了時に通知

---

## 6. 主要凍結期間 (Draft)

| 期間 | 理由 | カレンダー |
|---|---|---|
| 年末年始 (12/29-1/4) | 全社停止期間 | freeze-yearend |
| 月末月初 (要顧客確認) | 業務集中 | freeze-monthend |
| キャンペーン期間中 | クーポン発行ピーク | freeze-campaign (動的追加) |
| 監査前後 (要協議) | 監査エビデンス確保 | (要協議) |
| 主要システム更新時 | 親システム連動 | (要協議) |

---

## 7. テスト計画

### 7.1 UT (要件定義 + 詳細設計時)
- カレンダー定義の妥当性確認 (iCalendar 構文)
- TZ 変換確認 (UTC ↔ JST)

### 7.2 構築時 (LT 環境)
- `aws ssm get-calendar-state` でステート取得
- CLOSED 期間中の apply ブロック確認
- OPEN 期間中の apply 成功確認

### 7.3 結合試験
- CI/CD パイプラインから Change Calendar 経由 apply
- 凍結期間自動検知の動作確認

---

## 8. 既知の制約

| 制約 | 影響 | 対策 |
|---|---|---|
| iCalendar 時刻は UTC のみ | JST との変換間違いリスク | Terraform output で JST 表記併記 |
| カレンダー名は変更不可 | 名前ミスは作り直し | 命名規則を Day-1 で確定 |
| GetCalendarState は API レート制限 | 大量 CI 実行で 429 リスク | キャッシュ + リトライ |
| カレンダー間 AND 評価のみ | OR 評価不可 | 設計時に複数カレンダーで AND 構造設計 |

---

## 9. Exit Criteria

- [ ] 全カレンダー定義完了
- [ ] CI/CD パイプライン連携稼働
- [ ] 凍結期間自動通知稼働 (24h 前)
- [ ] CLOSED 期間中の apply ブロック動作確認 (LT 環境で検証済)
- [ ] 緊急時 Override 手順整備
- [ ] 監査ログ取得確認

---

## 10. 出典

- AWS Systems Manager Change Calendar https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/systems-manager-change-calendar.html
- AWS Systems Manager Change Calendar イベントの作成 https://docs.aws.amazon.com/ja_jp/systems-manager/latest/userguide/change-calendar-create-event.html
- GetCalendarState API https://docs.aws.amazon.com/systems-manager/latest/userguide/change-calendar-getstate.html
- iCalendar 仕様 RFC 5545 https://datatracker.ietf.org/doc/html/rfc5545
- AWS Provider aws_ssm_document https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document
