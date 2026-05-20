terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

# SNS Topics (重要度別)
resource "aws_sns_topic" "alert" {
  for_each = toset(["p1", "p2", "p3", "security", "cost"])

  name              = "${var.prefix}-alert-${each.key}"
  kms_master_key_id = var.kms_key_arn

  tags = var.tags
}

# CloudWatch Alarm: API 5xx エラー率
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.alb_arn_suffix != null ? 1 : 0

  alarm_name          = "${var.prefix}-alb-5xx"
  alarm_description   = "ALB 5xx error rate above threshold (P1)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  threshold           = 10
  datapoints_to_alarm = 3
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "errors"
    return_data = true
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  alarm_actions = [aws_sns_topic.alert["p1"].arn]
  ok_actions    = [aws_sns_topic.alert["p1"].arn]

  tags = var.tags
}

# CloudWatch Alarm: Aurora CPU
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  count = var.aurora_cluster_id != null ? 1 : 0

  alarm_name          = "${var.prefix}-aurora-cpu-high"
  alarm_description   = "Aurora CPU above 80% (P2)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 15
  threshold           = 80
  datapoints_to_alarm = 10
  treat_missing_data  = "notBreaching"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alert["p2"].arn]
  ok_actions    = [aws_sns_topic.alert["p2"].arn]

  tags = var.tags
}

# CloudWatch Alarm: Aurora 接続数
resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  count = var.aurora_cluster_id != null ? 1 : 0

  alarm_name          = "${var.prefix}-aurora-connections-high"
  alarm_description   = "Aurora connections above 80% of max (P2)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  threshold           = var.aurora_max_connections * 0.8
  datapoints_to_alarm = 3
  treat_missing_data  = "notBreaching"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alert["p2"].arn]

  tags = var.tags
}

# CloudWatch Alarm: Aurora Failover 検知
resource "aws_cloudwatch_metric_alarm" "aurora_failover" {
  count = var.aurora_cluster_id != null ? 1 : 0

  alarm_name          = "${var.prefix}-aurora-failover"
  alarm_description   = "Aurora failover detected (P1)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"
  metric_name         = "FailoverCapableDBClusterToPrimaryFailover" # 例 (要確認: 実メトリクス名は engine version 依存)
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alert["p1"].arn]

  tags = var.tags
}

data "aws_caller_identity" "current" {}

# Cost Anomaly Detection サービスから cost トピックへ publish できるようにする。
# costalerts.amazonaws.com は SNS:Publish 権限が無いとサブスクリプション作成自体失敗 or
# サイレントに通知失敗するため、トピックポリシーで明示許可する。
# 参考: AWS Cost Anomaly Detection 公式ドキュメント / Terraform aws_ce_anomaly_subscription 例。
resource "aws_sns_topic_policy" "cost_anomaly" {
  arn = aws_sns_topic.alert["cost"].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCostAnomalyDetectionPublish"
        Effect    = "Allow"
        Principal = { Service = "costalerts.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.alert["cost"].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:ce::${data.aws_caller_identity.current.account_id}:anomalysubscription/*"
          }
        }
      }
    ]
  })
}

# Cost Anomaly Detection (案件用)
resource "aws_ce_anomaly_monitor" "this" {
  name              = "${var.prefix}-cost-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = var.tags
}

resource "aws_ce_anomaly_subscription" "this" {
  name             = "${var.prefix}-cost-subscription"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.this.arn]
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["30"] # 30% 増で通知
    }
  }
  subscriber {
    type    = "SNS"
    address = aws_sns_topic.alert["cost"].arn
  }

  # トピックポリシーが先に作られていないと Cost Anomaly Detection が publish 検証で失敗する。
  depends_on = [aws_sns_topic_policy.cost_anomaly]
}
