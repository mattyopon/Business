output "cluster_id" {
  description = "ECS Cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS Cluster 名"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "service_names" {
  description = "作成された ECS Service 名リスト"
  value       = [for s in aws_ecs_service.this : s.name]
}

output "task_definition_arns" {
  description = "Task Definition ARN マップ"
  value       = { for k, v in aws_ecs_task_definition.service : k => v.arn }
}
