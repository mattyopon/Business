output "trail_arn" {
  value       = aws_cloudtrail.this.arn
  description = "CloudTrail ARN"
}

output "trail_name" {
  value       = aws_cloudtrail.this.name
  description = "CloudTrail name"
}

output "cwlogs_group_arn" {
  value       = aws_cloudwatch_log_group.trail.arn
  description = "CloudTrail CloudWatch Logs group ARN"
}

output "lake_arn" {
  value       = try(aws_cloudtrail_event_data_store.lake[0].arn, null)
  description = "CloudTrail Lake event data store ARN"
}
