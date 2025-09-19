#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Install jq for JSON parsing
yum install -y jq

# Get AWS region with fallback
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)
if [ -z "$REGION" ]; then
    # Fallback to hardcoded region
    REGION="eu-north-1"
    echo "Failed to get region from metadata, using fallback: $REGION"
else
    echo "Detected AWS region: $REGION"
fi

# Use hardcoded ECR URL to avoid AWS CLI issues
ECR_REPO="011528268572.dkr.ecr.$REGION.amazonaws.com/simple-website"
echo "Using ECR Repository URL: $ECR_REPO"

# Login to ECR with proper region handling
echo "Logging into ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create environment file with database credentials from Secrets Manager
cat > .env << EOF
DB_HOST=${db_endpoint}
DB_USER=${db_username}
DB_PASSWORD="${db_password}"
DB_NAME=${db_name}
PORT=3000
EOF

# Create Docker Compose file
cat > docker-compose.yml << EOF
services:
  app:
    image: $ECR_REPO:latest
    ports:
      - "3000:3000"
    env_file:
      - .env
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# Debug: Print environment variables and docker-compose file
echo "=== Environment Variables ==="
cat .env
echo "=== Docker Compose File ==="
cat docker-compose.yml

# Pull the image first to check if it exists
echo "Pulling Docker image..."
docker pull "$ECR_REPO:latest"

# Start the application
echo "Starting application with docker-compose..."
docker-compose up -d

# Wait for application to start
sleep 30

# Check if application is running
echo "=== Docker Compose Status ==="
docker-compose ps

echo "=== Docker Images ==="
docker images

echo "=== Testing local endpoints ==="
curl -f http://localhost:3000/status || echo "Status endpoint failed"
curl -f http://localhost:3000/health || echo "Health endpoint failed"

if docker-compose ps | grep -q "Up"; then
    echo "Application started successfully"
else
    echo "Application failed to start"
    echo "Docker Compose Logs:"
    docker-compose logs
fi

# Create a script to retry pulling the image if it fails
cat > /opt/app/retry-pull.sh << 'EOF'
#!/bin/bash
while true; do
    if ! docker-compose ps | grep -q "Up"; then
        echo "$(date): Application not running, retrying..."
        docker-compose pull
        docker-compose up -d
        sleep 30
    else
        echo "$(date): Application is running"
        sleep 120
    fi
done
EOF

chmod +x /opt/app/retry-pull.sh

# Start the retry script in background
nohup /opt/app/retry-pull.sh > /var/log/app-retry.log 2>&1 &

# Install CloudWatch agent for monitoring
yum install -y amazon-cloudwatch-agent

# Create CloudWatch agent config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

echo "User data script completed successfully"
