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

locals {
  common_tags = {
    Environment = var.environment
    Project     = "SimpleWebsite"
    ManagedBy   = "Terraform"
  }
}
