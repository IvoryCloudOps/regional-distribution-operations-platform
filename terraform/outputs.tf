#--------------------------------
# Outputs
#--------------------------------

output "github_actions_oidc_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
  value       = aws_iam_role.github_actions_oidc_role.arn
}

output "alb_dns_name" {
  description = "DNS name of the internal ALB"
  value       = aws_lb.distribution_internal_alb.dns_name
}

output "s3_bucket_name" {
  description = "Name of the distribution application S3 bucket"
  value       = aws_s3_bucket.distribution_bucket.id
}
