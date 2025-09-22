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

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

variable "db_secret_name" {
  description = "Name for the database credentials secret in AWS Secrets Manager"
  type        = string
  default     = "mysql-db-credentials-v3"
}

variable "rds_instance_identifier" {
  description = "Identifier for the RDS MySQL instance"
  type        = string
  default     = "myapp-mysql-db"
}

variable "ssh_key_name" {
  description = "Name for the EC2 SSH key pair"
  type        = string
  default     = "app-ssh-key"
}

variable "app_port" {
  description = "Port for the Node.js application"
  type        = number
  default     = 3000
}

variable "db_port" {
  description = "Port for the MySQL database"
  type        = number
  default     = 3306
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "SimpleWebsite"
    ManagedBy   = "Terraform"
  }
}
