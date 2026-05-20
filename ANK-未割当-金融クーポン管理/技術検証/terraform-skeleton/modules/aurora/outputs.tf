output "cluster_identifier" {
  description = "Aurora Cluster Identifier"
  value       = local.cluster_identifier
}

output "cluster_endpoint" {
  description = "Aurora Cluster Writer Endpoint"
  value       = local.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora Cluster Reader Endpoint"
  value       = local.cluster_reader_endpoint
}

output "port" {
  description = "Aurora Port"
  value       = local.cluster_port
}

output "master_user_secret_arn" {
  description = "Master User Secret ARN (Secrets Manager)"
  value       = local.cluster_master_user_secret[0].secret_arn
  sensitive   = true
}

output "cluster_arn" {
  description = "Aurora Cluster ARN"
  value       = local.cluster_arn
}

output "instance_endpoints" {
  description = "各 Aurora インスタンスの Endpoint"
  value       = aws_rds_cluster_instance.this[*].endpoint
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID (IAM DB Auth で使用)"
  value       = local.cluster_resource_id
}

output "global_cluster_id" {
  description = "Aurora Global Cluster identifier (secondary region cluster の global_cluster_identifier に使用)"
  value       = try(aws_rds_global_cluster.this[0].id, null)
}

output "global_cluster_arn" {
  description = "Aurora Global Cluster ARN"
  value       = try(aws_rds_global_cluster.this[0].arn, null)
}
