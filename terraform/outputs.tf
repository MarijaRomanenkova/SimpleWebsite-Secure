output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "cloudfront_domain" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.app.domain_name
}

output "rds_endpoint" {
  description = "The RDS endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "db_secret_name" {
  description = "The name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "aws_region" {
  description = "The AWS region used for deployment"
  value       = var.aws_region
}
