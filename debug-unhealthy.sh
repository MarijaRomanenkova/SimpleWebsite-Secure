#!/bin/bash

echo "🔍 COMPREHENSIVE DEBUGGING OF UNHEALTHY INSTANCES"
echo "=================================================="

# Get the latest instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=terraform-20250919113456709500000006" \
  --query 'Reservations[*].Instances[*].[InstanceId,LaunchTime]' \
  --output text | sort -k2 | tail -1 | awk '{print $1}')

echo "Latest instance: $INSTANCE_ID"
echo ""

# 1. Check console output
echo "📋 1. CONSOLE OUTPUT (last 30 lines):"
echo "------------------------------------"
aws ec2 get-console-output --instance-id $INSTANCE_ID --query 'Output' --output text | tail -30
echo ""

# 2. Check instance status
echo "🖥️  2. INSTANCE STATUS:"
echo "---------------------"
aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].{State:State.Name,LaunchTime:LaunchTime,PrivateIP:PrivateIpAddress}' --output table
echo ""

# 3. Check target group health
echo "🎯 3. TARGET GROUP HEALTH:"
echo "------------------------"
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-north-1:011528268572:targetgroup/app-target-group-v3/6143cb5d48374a8d --query 'TargetHealthDescriptions[*].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' --output table
echo ""

# 4. Try to run commands via Systems Manager
echo "🐳 4. DOCKER STATUS (via Systems Manager):"
echo "----------------------------------------"
COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo \"=== DOCKER PS ===\"",
    "docker ps -a",
    "echo \"=== DOCKER COMPOSE PS ===\"",
    "cd /opt/app && docker-compose ps",
    "echo \"=== DOCKER IMAGES ===\"",
    "docker images",
    "echo \"=== SYSTEMCTL STATUS ===\"",
    "systemctl status docker",
    "echo \"=== NETSTAT ===\"",
    "netstat -tlnp | grep :3000",
    "echo \"=== CURL LOCAL ===\"",
    "curl -f http://localhost:3000/status || echo \"Status endpoint failed\"",
    "curl -f http://localhost:3000/health || echo \"Health endpoint failed\"",
    "echo \"=== PROCESSES ===\"",
    "ps aux | grep -E \"(node|npm|docker)\""
  ]' \
  --query 'Command.CommandId' \
  --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "Command sent: $COMMAND_ID"
    echo "Waiting 15 seconds for execution..."
    sleep 15
    
    echo "Command output:"
    aws ssm get-command-invocation \
      --command-id $COMMAND_ID \
      --instance-id $INSTANCE_ID \
      --query 'StandardOutputContent' \
      --output text 2>/dev/null || echo "Failed to get command output"
else
    echo "Failed to send Systems Manager command"
fi

echo ""
echo "🔧 5. ALB HEALTH CHECK CONFIGURATION:"
echo "------------------------------------"
aws elbv2 describe-target-groups --target-group-arns arn:aws:elasticloadbalancing:eu-north-1:011528268572:targetgroup/app-target-group-v3/6143cb5d48374a8d --query 'TargetGroups[*].HealthCheck' --output table

echo ""
echo "🌐 6. TESTING LOAD BALANCER DIRECTLY:"
echo "------------------------------------"
echo "Testing ALB endpoint:"
curl -v --max-time 10 http://app-load-balancer-1386763610.eu-north-1.elb.amazonaws.com/status 2>&1 | head -20

echo ""
echo "Testing health endpoint:"
curl -v --max-time 10 http://app-load-balancer-1386763610.eu-north-1.elb.amazonaws.com/health 2>&1 | head -20
