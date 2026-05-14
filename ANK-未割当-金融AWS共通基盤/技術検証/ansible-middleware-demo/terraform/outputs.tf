# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "web_server_public_ips" {
  description = "Web server public IPs"
  value       = aws_instance.web[*].public_ip
}

output "web_server_private_ips" {
  description = "Web server private IPs"
  value       = aws_instance.web[*].private_ip
}

output "app_server_private_ips" {
  description = "App server private IPs"
  value       = aws_instance.app[*].private_ip
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

# JSON出力（Ansible用）
output "ansible_vars" {
  description = "Variables for Ansible"
  value = {
    web_servers = [
      for i, instance in aws_instance.web : {
        name       = instance.tags["Name"]
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
      }
    ]
    app_servers = [
      for i, instance in aws_instance.app : {
        name       = instance.tags["Name"]
        private_ip = instance.private_ip
      }
    ]
    alb_dns_name = aws_lb.main.dns_name
    environment  = var.environment
  }
}
