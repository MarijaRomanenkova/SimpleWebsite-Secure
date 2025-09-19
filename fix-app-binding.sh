#!/bin/bash

# Fix application binding issue
set -e

echo "🔧 Fixing application binding issue..."

# Get ECR URL and region from Terraform
REPO_URL=$(cd terraform && terraform output -raw repository_url)
AWS_REGION=$(cd terraform && terraform output -raw aws_region 2>/dev/null || echo "eu-north-1")

echo "📦 Building and pushing updated Docker image..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REPO_URL

# Build, tag, and push the updated image
docker buildx build --platform linux/amd64 -t simple-website .
docker tag simple-website:latest $REPO_URL:latest
docker push $REPO_URL:latest

echo "✅ Updated Docker image pushed to ECR!"

# Force another instance refresh to pull the new image
echo "🔄 Starting instance refresh to pull updated image..."
ASG_NAME="terraform-20250919090737026400000006"

REFRESH_ID=$(aws autoscaling start-instance-refresh --auto-scaling-group-name $ASG_NAME --preferences MinHealthyPercentage=50,InstanceWarmup=300 --query 'InstanceRefreshId' --output text)

echo "✅ Instance refresh started: $REFRESH_ID"

echo ""
echo "🎯 The fix applied:"
echo "   - Changed app.listen(PORT) to app.listen(PORT, '0.0.0.0')"
echo "   - This allows the app to accept connections from all interfaces"
echo "   - Load balancer health checks should now work"
echo ""
echo "⏳ The instance refresh will take 5-10 minutes to complete."
echo "💡 Monitor progress with: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --instance-refresh-ids $REFRESH_ID"
echo ""
echo "🔍 Check target group health with:"
echo "   aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-north-1:011528268572:targetgroup/app-target-group-v3/59f05debaab0e911"
