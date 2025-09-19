# Simple Website with AWS Infrastructure

A secure, scalable website with contact form functionality, deployed on AWS using Terraform with Docker containerization.

## 🏗️ Architecture

This project implements a complete AWS infrastructure with:
- **CloudFront CDN** for global content delivery
- **Application Load Balancer** for high availability
- **EC2 Auto Scaling** with Docker containers
- **RDS MySQL** database with multi-AZ deployment
- **AWS Secrets Manager** for secure credential management
- **CloudWatch** monitoring and auto-scaling policies

## 📋 Prerequisites

Before running this project, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured with your credentials
3. **Terraform** (v1.0+) installed
4. **Docker** installed
5. **Node.js** (v16+) installed (for local development)
6. **Git** installed

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone https://github.com/MarijaRomanenkova/SimpleWebsite-Secure.git
cd SimpleWebsite-Secure
```

### Step 2: Configure AWS Credentials

Set up your AWS credentials:

```bash
aws configure
```

Or set environment variables:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-north-1"
```

### Step 3: Configure Variables

The `deploy-infrastructure.sh` script will automatically create `terraform/terraform.tfvars` with:
- **AWS Account ID** (auto-detected from your AWS CLI)
- **AWS Region** (auto-detected from your AWS CLI configuration)
- **VPC CIDR** (default: 10.0.0.0/16)
- **Environment** (default: production)

**Database Configuration:**
- **DB_PASSWORD**: Automatically generated secure password stored in AWS Secrets Manager
- **DB_NAME**: Automatically set to `myappdb`
- **DB_HOST**: Automatically set to RDS endpoint
- **DB_USER**: Automatically set to `root`

### Step 4: Deploy Infrastructure

**Automated Infrastructure Deployment:**
```bash
./deploy-infrastructure.sh
```

This script will:
- ✅ Automatically create `terraform.tfvars` with your AWS account ID
- ✅ Initialize and plan the infrastructure
- ✅ Deploy all AWS resources (VPC, EC2, RDS, ALB, CloudFront, etc.)
- ✅ Show you the key outputs

**Note:** This will create AWS resources that may incur costs. The deployment takes 10-15 minutes.

### Step 5: Deploy Application

**Automated Application Deployment:**
```bash
./quick-deploy.sh
```

This script will:
- ✅ Build your Docker image
- ✅ Push it to ECR
- ✅ Wait for EC2 instances to start the application
- ✅ Monitor health checks until targets are healthy
- ✅ Provide your application URL

### Step 6: Access Your Application

After deployment, get your application URL:

```bash
cd terraform
terraform output cloudfront_url
```

Visit the URL in your browser to see your deployed application!

## ✅ Verify Your Deployment

### Automated Verification
```bash
./check-deployment.sh
```


## 📁 Project Structure

```
SimpleWebsite-Secure/
├── app.js                          # Node.js application
├── config/
│   └── db.js                       # Database configuration
├── public/                         # Static files
│   ├── index.html                  # Main page
│   ├── messages.html               # Messages display page
│   ├── script.js                  # Frontend JavaScript
│   └── styles.css                 # CSS styles
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                # Output values
│   ├── user-data.sh               # EC2 startup script
│   └── terraform.tfvars           # Your configuration (auto-created)
├── Dockerfile                     # Docker configuration
├── init.sql                       # Database schema
├── package.json                   # Node.js dependencies
├── deploy-infrastructure.sh       # Infrastructure deployment script
├── quick-deploy.sh                # Application deployment script
├── check-deployment.sh            # AWS verification script
├── terraform.tfvars.example       # Configuration template
└── README.md                      # This file
```
