#!/bin/bash

# Fix ECR repository URL issue
set -e

echo "🔧 Fixing ECR repository URL issue..."

# Step 1: Update the infrastructure with the fixed user-data script
echo "📝 Step 1: Updating infrastructure with fixed ECR handling..."
cd terraform

# Apply the updated user-data script
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

cd ..

echo "✅ Infrastructure updated with ECR fixes!"

# Step 2: Force another instance refresh
echo "🔄 Step 2: Starting instance refresh to apply fixes..."
ASG_NAME="terraform-20250919090737026400000006"

REFRESH_ID=$(aws autoscaling start-instance-refresh --auto-scaling-group-name $ASG_NAME --preferences MinHealthyPercentage=50,InstanceWarmup=300 --query 'InstanceRefreshId' --output text)

echo "✅ Instance refresh started: $REFRESH_ID"

echo ""
echo "🎯 The fixes applied:"
echo "   - Added error handling for ECR repository URL retrieval"
echo "   - Added fallback hardcoded ECR URL"
echo "   - Added better error handling for ECR login"
echo "   - Added more debugging output"
echo ""
echo "⏳ The instance refresh will take 5-10 minutes to complete."
echo "💡 Monitor progress with: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --instance-refresh-ids $REFRESH_ID"
echo ""
echo "🔍 Check target group health with:"
echo "   aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-north-1:011528268572:targetgroup/app-target-group-v3/59f05debaab0e911"
