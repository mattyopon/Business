output "web_acl_arn" {
  value       = aws_wafv2_web_acl.this.arn
  description = "WAFv2 Web ACL ARN"
}

output "web_acl_id" {
  value       = aws_wafv2_web_acl.this.id
  description = "WAFv2 Web ACL ID"
}

output "log_group_name" {
  value       = try(aws_cloudwatch_log_group.waf[0].name, null)
  description = "WAF CloudWatch Logs group name"
}
