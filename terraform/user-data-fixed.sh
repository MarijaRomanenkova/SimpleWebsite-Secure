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

# Get AWS region
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "Detected AWS region: $REGION"

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

# Pull and start the application
echo "Pulling Docker image..."
docker pull "$ECR_REPO:latest"

echo "Starting application..."
docker-compose up -d

# Wait and check status
sleep 30
echo "=== Docker Compose Status ==="
docker-compose ps

echo "=== Docker Images ==="
docker images

echo "=== Testing local endpoints ==="
curl -f http://localhost:3000/status || echo "Status endpoint failed"
curl -f http://localhost:3000/health || echo "Health endpoint failed"

echo "User-data script completed successfully"
