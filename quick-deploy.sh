#!/bin/bash

# Quick deployment script - one command deployment
# Usage: ./quick-deploy.sh

set -e

echo "🚀 Quick Deploy - Building and pushing to AWS..."

# Get ECR URL and region from Terraform
REPO_URL=$(cd terraform && terraform output -raw repository_url)
AWS_REGION=$(cd terraform && terraform output -raw aws_region 2>/dev/null || echo "eu-north-1")

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URL

# Build, tag, and push
docker buildx build --platform linux/amd64 -t simple-website .
docker tag simple-website:latest $REPO_URL:latest
docker push $REPO_URL:latest

echo "✅ Docker image pushed to ECR!"

# Wait for EC2 instances to pull and start the application
echo "⏳ Waiting for EC2 instances to start the application..."
echo "💡 The instances will now automatically retry pulling the image every 2 minutes"

# Get target group ARN
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --query 'TargetGroups[0].TargetGroupArn' --output text)

# Wait for healthy targets
MAX_ATTEMPTS=20
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    HEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' --output text)
    
    if [ "$HEALTHY_COUNT" -gt 0 ]; then
        echo "✅ Found $HEALTHY_COUNT healthy target(s)!"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo "⏳ Attempt $ATTEMPT/$MAX_ATTEMPTS - Waiting for healthy targets..."
    echo "   (Instances are retrying to pull the image automatically)"
    sleep 30
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "⚠️  Timeout waiting for healthy targets."
    echo "💡 The instances are still retrying automatically. Check status with: ./check-deployment.sh"
fi

echo "✅ Deployment complete!"
echo "🌐 Your app is available at: https://$(cd terraform && terraform output -raw cloudfront_domain)"
echo "💡 Note: It may take a few more minutes for CloudFront to fully propagate the changes."
