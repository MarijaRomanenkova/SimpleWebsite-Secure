#!/bin/bash

# AWS Infrastructure Deployment Script
# Usage: ./deploy-infrastructure.sh

set -e

echo "🏗️  Deploying AWS Infrastructure..."

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars..."
    
    # Get AWS account ID automatically
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Get AWS region automatically
    AWS_REGION=$(aws configure get region || echo "eu-north-1")
    
    # Create terraform.tfvars directly
    cat > terraform/terraform.tfvars << EOF
vpc_cidr      = "10.0.0.0/16"
environment   = "production"
aws_account_id = "$AWS_ACCOUNT_ID"
aws_region    = "$AWS_REGION"
EOF
    
    echo "✅ terraform.tfvars created with AWS Account ID: $AWS_ACCOUNT_ID"
else
    echo "✅ terraform.tfvars already exists"
fi

# Deploy infrastructure
cd terraform

echo "🚀 Initializing Terraform..."
terraform init

echo "📋 Planning infrastructure deployment..."
terraform plan -out=tfplan

echo "🏗️  Applying infrastructure (this may take 10-15 minutes)..."
terraform apply -auto-approve tfplan

echo "✅ Infrastructure deployed successfully!"

# Show key outputs
echo ""
echo "📊 Infrastructure Summary:"
echo "ECR Repository: $(terraform output -raw repository_url)"
echo "CloudFront URL: https://$(terraform output -raw cloudfront_domain)"
echo "ALB URL: http://$(terraform output -raw alb_dns_name)"
echo "RDS Endpoint: $(terraform output -raw rds_endpoint)"

cd ..

# Cleanup
rm -f terraform/tfplan

echo ""
echo "🎉 Infrastructure deployment complete!"
echo "💡 Next step: Run './quick-deploy.sh' to deploy your application"
