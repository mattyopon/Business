output "ecs_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value       = aws_iam_role.ecs_execution.arn
}

output "aurora_monitoring_role_arn" {
  description = "Aurora Enhanced Monitoring Role ARN"
  value       = aws_iam_role.aurora_monitoring.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC Provider ARN (作成した場合)"
  value       = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "cicd_plan_role_arn" {
  description = "CI/CD Plan Role ARN"
  value       = var.create_cicd_roles ? aws_iam_role.cicd_plan[0].arn : null
}

output "cicd_apply_role_arn" {
  description = "CI/CD Apply Role ARN"
  value       = var.create_cicd_roles ? aws_iam_role.cicd_apply[0].arn : null
}
