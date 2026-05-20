output "private_zone_id" {
  description = "Private Hosted Zone ID"
  value       = var.create_private_zone ? aws_route53_zone.private[0].zone_id : null
}

output "public_zone_id" {
  description = "Public Hosted Zone ID"
  value       = var.create_public_zone ? aws_route53_zone.public[0].zone_id : null
}
