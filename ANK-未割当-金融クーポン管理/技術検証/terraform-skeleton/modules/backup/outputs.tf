output "vault_arn" {
  value       = aws_backup_vault.primary.arn
  description = "Primary backup vault ARN"
}

output "vault_name" {
  value       = aws_backup_vault.primary.name
  description = "Primary backup vault name"
}

output "plan_arn" {
  value       = aws_backup_plan.this.arn
  description = "Backup plan ARN"
}
