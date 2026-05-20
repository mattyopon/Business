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
