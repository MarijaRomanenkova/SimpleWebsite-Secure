variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod, staging)"
  type        = string
  default     = "dev"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  sensitive   = true
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "SimpleWebsite"
    ManagedBy   = "Terraform"
  }
}
