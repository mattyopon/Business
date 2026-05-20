output "cluster_identifier" {
  description = "Aurora Cluster Identifier"
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_endpoint" {
  description = "Aurora Cluster Writer Endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora Cluster Reader Endpoint"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "Aurora Port"
  value       = aws_rds_cluster.this.port
}

output "master_user_secret_arn" {
  description = "Master User Secret ARN (Secrets Manager)"
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
  sensitive   = true
}

output "cluster_arn" {
  description = "Aurora Cluster ARN"
  value       = aws_rds_cluster.this.arn
}

output "instance_endpoints" {
  description = "各 Aurora インスタンスの Endpoint"
  value       = aws_rds_cluster_instance.this[*].endpoint
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID (IAM DB Auth で使用)"
  value       = aws_rds_cluster.this.cluster_resource_id
}

output "global_cluster_id" {
  description = "Aurora Global Cluster identifier (secondary region cluster の global_cluster_identifier に使用)"
  value       = try(aws_rds_global_cluster.this[0].id, null)
}

output "global_cluster_arn" {
  description = "Aurora Global Cluster ARN"
  value       = try(aws_rds_global_cluster.this[0].arn, null)
}
