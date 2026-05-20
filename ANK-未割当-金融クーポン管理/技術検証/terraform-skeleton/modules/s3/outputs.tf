output "bucket_ids" {
  description = "作成された S3 バケット ID マップ"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  description = "作成された S3 バケット ARN マップ"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}
