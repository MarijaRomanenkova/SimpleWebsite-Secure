#!/bin/bash

# Debug script for EC2 instances
set -e

echo "🔍 Debugging EC2 Instances..."

# Get instance IDs
INSTANCE_1="i-03defb6bc4af6cba8"
INSTANCE_2="i-072b5d59d2448fa96"

echo "📋 Instance Information:"
aws ec2 describe-instances --instance-ids $INSTANCE_1 $INSTANCE_2 --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,SubnetId]' --output table

echo ""
echo "🏥 Target Group Health:"
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-north-1:011528268572:targetgroup/app-target-group-v3/59f05debaab0e911

echo ""
echo "📊 Auto Scaling Group Status:"
aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,Instances | length(@),Instances[*].[InstanceId,LifecycleState,HealthStatus]]' --output table

echo ""
echo "🔧 Instance Console Output (Last 100 lines):"
echo "Instance 1 ($INSTANCE_1):"
aws ec2 get-console-output --instance-id $INSTANCE_1 --query 'Output' --output text | tail -100

echo ""
echo "Instance 2 ($INSTANCE_2):"
aws ec2 get-console-output --instance-id $INSTANCE_2 --query 'Output' --output text | tail -100

echo ""
echo "💡 Next Steps:"
echo "1. Check if Docker containers are running on instances"
echo "2. Verify application is listening on port 3000"
echo "3. Check if health endpoint /health is responding"
echo "4. Consider moving instances to public subnets for easier debugging"
