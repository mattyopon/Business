output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR ブロック"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet ID リスト"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private App Subnet ID リスト"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "Private DB Subnet ID リスト"
  value       = aws_subnet.private_db[*].id
}

output "isolated_batch_subnet_ids" {
  description = "Isolated Batch Subnet ID リスト"
  value       = aws_subnet.isolated_batch[*].id
}

output "db_subnet_group_name" {
  description = "DB Subnet Group 名"
  value       = aws_db_subnet_group.this.name
}

output "availability_zones" {
  description = "使用 AZ リスト"
  value       = local.azs
}
