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

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  description = "The ARN of the Application Load Balancer target group"
  value       = aws_lb_target_group.app.arn
}

output "ssh_key_name" {
  description = "The name of the SSH key pair created in AWS"
  value       = aws_key_pair.app_key.key_name
}
