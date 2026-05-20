output "sns_topic_arns" {
  description = "SNS Topic ARN マップ (重要度別)"
  value       = { for k, v in aws_sns_topic.alert : k => v.arn }
}

output "cost_anomaly_monitor_arn" {
  description = "Cost Anomaly Monitor ARN"
  value       = aws_ce_anomaly_monitor.this.arn
}
