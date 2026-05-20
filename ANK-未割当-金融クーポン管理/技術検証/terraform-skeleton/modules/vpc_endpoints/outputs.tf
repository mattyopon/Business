output "s3_gateway_endpoint_id" {
  value       = try(aws_vpc_endpoint.s3_gateway[0].id, null)
  description = "S3 Gateway VPC Endpoint ID"
}

output "dynamodb_gateway_endpoint_id" {
  value       = try(aws_vpc_endpoint.dynamodb_gateway[0].id, null)
  description = "DynamoDB Gateway VPC Endpoint ID"
}

output "interface_endpoint_ids" {
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
  description = "Interface VPC Endpoint ID map (service => id)"
}

output "interface_endpoint_sg_id" {
  value       = try(aws_security_group.interface[0].id, null)
  description = "Interface endpoint shared SG ID"
}
