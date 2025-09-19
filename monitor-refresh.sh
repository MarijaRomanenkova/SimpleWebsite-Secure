#!/bin/bash

# Monitor instance refresh progress
set -e

REFRESH_ID="56d8afb1-398f-4af3-b51e-c4d2ecf4508f"
ASG_NAME="terraform-20250919090737026400000006"
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:eu-north-1:011528268572:targetgroup/app-target-group-v3/59f05debaab0e911"

echo "🔄 Monitoring instance refresh progress..."
echo "Refresh ID: $REFRESH_ID"
echo ""

while true; do
    # Check refresh status
    REFRESH_STATUS=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --instance-refresh-ids $REFRESH_ID --query 'InstanceRefreshes[0].Status' --output text)
    
    echo "📊 Refresh Status: $REFRESH_STATUS"
    
    # Check target group health
    HEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' --output text)
    TOTAL_TARGETS=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions | length(@)' --output text)
    
    echo "🏥 Healthy Targets: $HEALTHY_COUNT/$TOTAL_TARGETS"
    
    # Show all target health statuses
    aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
    
    if [ "$REFRESH_STATUS" = "Successful" ]; then
        echo "✅ Instance refresh completed successfully!"
        if [ "$HEALTHY_COUNT" -gt 0 ]; then
            echo "🎉 Application is healthy!"
            break
        else
            echo "⚠️  Refresh completed but no healthy targets yet. Waiting..."
        fi
    elif [ "$REFRESH_STATUS" = "Failed" ]; then
        echo "❌ Instance refresh failed!"
        break
    elif [ "$REFRESH_STATUS" = "Cancelled" ]; then
        echo "⏹️  Instance refresh was cancelled!"
        break
    else
        echo "⏳ Refresh still in progress. Waiting 30 seconds..."
        sleep 30
    fi
    
    echo "----------------------------------------"
done

echo ""
echo "🌐 Testing application URLs..."

# Test CloudFront URL
CLOUDFRONT_URL=$(cd terraform && terraform output -raw cloudfront_domain 2>/dev/null || echo "")
if [ ! -z "$CLOUDFRONT_URL" ]; then
    echo "Testing CloudFront: https://$CLOUDFRONT_URL"
    if curl -s --head "https://$CLOUDFRONT_URL" | head -n 1 | grep -q "200"; then
        echo "✅ CloudFront is responding with 200 OK"
    else
        echo "⚠️  CloudFront response: $(curl -s --head "https://$CLOUDFRONT_URL" | head -n 1)"
    fi
fi

echo ""
echo "🎯 Deployment monitoring complete!"
