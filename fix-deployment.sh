#!/bin/bash

# Fix deployment script
set -e

echo "🔧 Fixing deployment issues..."

# Step 1: Update the infrastructure with the fixed user-data script
echo "📝 Step 1: Updating infrastructure with fixed user-data script..."
cd terraform

# Apply the updated user-data script
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

cd ..

echo "✅ Infrastructure updated!"

# Step 2: Wait a moment for instances to start updating
echo "⏳ Waiting for instances to update..."
sleep 60

# Step 3: Check the status
echo "🔍 Checking deployment status..."
./check-deployment.sh

echo ""
echo "💡 If instances are still unhealthy, run:"
echo "   ./debug-instances.sh"
echo ""
echo "🎯 The main fixes applied:"
echo "   - Fixed ECR login command"
echo "   - Added better error handling"
echo "   - Removed obsolete Docker Compose version"
echo "   - Added debugging output"
