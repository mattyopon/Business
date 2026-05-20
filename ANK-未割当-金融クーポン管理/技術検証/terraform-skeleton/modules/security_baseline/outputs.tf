output "guardduty_detector_id" {
  value       = try(aws_guardduty_detector.this[0].id, null)
  description = "GuardDuty detector ID"
}

output "security_hub_account_arn" {
  value       = try(aws_securityhub_account.this[0].arn, null)
  description = "Security Hub account ARN"
}

output "config_recorder_name" {
  value       = try(aws_config_configuration_recorder.this[0].name, null)
  description = "AWS Config recorder name"
}

output "macie_account_id" {
  value       = try(aws_macie2_account.this[0].id, null)
  description = "Macie account ID"
}
