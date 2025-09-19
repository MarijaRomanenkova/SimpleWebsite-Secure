#!/bin/bash

echo "🔍 Checking container status on EC2 instances..."

# Get the latest instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=terraform-20250919113456709500000006" \
  --query 'Reservations[*].Instances[*].[InstanceId,LaunchTime]' \
  --output text | sort -k2 | tail -1 | awk '{print $1}')

echo "Latest instance: $INSTANCE_ID"

# Get instance IP (private)
INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[*].Instances[*].PrivateIpAddress' \
  --output text)

echo "Instance IP: $INSTANCE_IP"

# Check if we can get console output
echo "📋 Getting console output..."
aws ec2 get-console-output --instance-id $INSTANCE_ID --query 'Output' --output text | tail -20

echo ""
echo "🐳 Checking Docker status via Systems Manager..."

# Try to run commands via Systems Manager
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker ps", "docker-compose ps", "systemctl status docker", "curl -f http://localhost:3000/status || echo \"Local status check failed\"", "curl -f http://localhost:3000/health || echo \"Local health check failed\""]' \
  --query 'Command.CommandId' \
  --output text

echo "Command sent. Waiting 10 seconds for execution..."
sleep 10

# Get command output
COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker ps", "docker-compose ps"]' \
  --query 'Command.CommandId' \
  --output text)

sleep 5

aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "🔧 If containers are not running, we may need to check the user-data script execution."
