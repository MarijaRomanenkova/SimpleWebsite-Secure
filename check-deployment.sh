#!/bin/bash

# AWS Deployment Verification Script
# This script checks if all AWS resources are working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[CHECKING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓ SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠ WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗ ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check AWS CLI configuration
check_aws_config() {
    print_header "AWS CLI Configuration"
    
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        print_success "AWS CLI is configured"
        print_status "Account ID: $ACCOUNT_ID"
        print_status "User: $USER_ARN"
    else
        print_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
}

# Check Terraform state
check_terraform_state() {
    print_header "Terraform State"
    
    if [ -d "terraform" ]; then
        cd terraform
        
        if terraform show &> /dev/null; then
            print_success "Terraform state is valid"
            
            # Get key outputs
            REPO_URL=$(terraform output -raw repository_url 2>/dev/null || echo "Not available")
            CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain 2>/dev/null || echo "Not available")
            ALB_URL=$(terraform output -raw alb_url 2>/dev/null || echo "Not available")
            
            print_status "ECR Repository: $REPO_URL"
            print_status "CloudFront URL: $CLOUDFRONT_URL"
            print_status "ALB URL: $ALB_URL"
        else
            print_error "Terraform state is invalid or resources not deployed"
            exit 1
        fi
        
        cd ..
    else
        print_error "Terraform directory not found"
        exit 1
    fi
}

# Check ECR repository
check_ecr() {
    print_header "ECR Repository"
    
    if [ ! -z "$REPO_URL" ] && [ "$REPO_URL" != "Not available" ]; then
        REPO_NAME=$(echo $REPO_URL | cut -d'/' -f2)
        
        if aws ecr describe-repositories --repository-names $REPO_NAME &> /dev/null; then
            print_success "ECR repository exists: $REPO_NAME"
            
            # Check for images
            IMAGE_COUNT=$(aws ecr list-images --repository-name $REPO_NAME --query 'imageIds | length(@)' --output text)
            if [ "$IMAGE_COUNT" -gt 0 ]; then
                print_success "Images found in repository: $IMAGE_COUNT"
                
                # Get latest image details
                LATEST_IMAGE=$(aws ecr list-images --repository-name $REPO_NAME --query 'imageIds[0].imageTag' --output text)
                print_status "Latest image tag: $LATEST_IMAGE"
            else
                print_warning "No images found in ECR repository"
            fi
        else
            print_error "ECR repository not found: $REPO_NAME"
        fi
    else
        print_warning "ECR repository URL not available from Terraform"
    fi
}

# Check EC2 instances
check_ec2() {
    print_header "EC2 Instances"
    
    INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*app*" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$INSTANCES" ]; then
        echo "$INSTANCES"
        
        RUNNING_COUNT=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*app*" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId' --output text | wc -w)
        print_success "Running EC2 instances: $RUNNING_COUNT"
        
        if [ "$RUNNING_COUNT" -gt 0 ]; then
            # Check if instances are healthy
            print_status "Checking instance health..."
            aws ec2 describe-instance-status --filters "Name=instance-state-name,Values=running" --query 'InstanceStatuses[*].[InstanceId,InstanceStatus.Status,SystemStatus.Status]' --output table
        fi
    else
        print_warning "No EC2 instances found with app tags"
    fi
}

# Check Auto Scaling Group
check_asg() {
    print_header "Auto Scaling Group"
    
    ASG_INFO=$(aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize,Instances | length(@)]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$ASG_INFO" ]; then
        echo "$ASG_INFO"
        print_success "Auto Scaling Group is configured"
    else
        print_warning "No Auto Scaling Groups found"
    fi
}

# Check Application Load Balancer
check_alb() {
    print_header "Application Load Balancer"
    
    ALB_INFO=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$ALB_INFO" ]; then
        echo "$ALB_INFO"
        print_success "Application Load Balancer is configured"
        
        # Check target groups
        TG_INFO=$(aws elbv2 describe-target-groups --query 'TargetGroups[*].[TargetGroupName,Protocol,Port,HealthCheckPath]' --output table 2>/dev/null || echo "")
        if [ ! -z "$TG_INFO" ]; then
            echo ""
            print_status "Target Groups:"
            echo "$TG_INFO"
        fi
    else
        print_warning "No Application Load Balancers found"
    fi
}

# Check RDS Database
check_rds() {
    print_header "RDS Database"
    
    RDS_INFO=$(aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,DBInstanceClass,Endpoint.Address]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$RDS_INFO" ]; then
        echo "$RDS_INFO"
        print_success "RDS database is configured"
        
        # Check if database is available
        DB_STATUS=$(aws rds describe-db-instances --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "Unknown")
        if [ "$DB_STATUS" = "available" ]; then
            print_success "Database is available"
        else
            print_warning "Database status: $DB_STATUS"
        fi
    else
        print_warning "No RDS databases found"
    fi
}

# Check CloudFront Distribution
check_cloudfront() {
    print_header "CloudFront Distribution"
    
    CF_INFO=$(aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Status,Comment]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$CF_INFO" ]; then
        echo "$CF_INFO"
        print_success "CloudFront distribution is configured"
        
        # Check distribution status
        CF_STATUS=$(aws cloudfront list-distributions --query 'DistributionList.Items[0].Status' --output text 2>/dev/null || echo "Unknown")
        if [ "$CF_STATUS" = "Deployed" ]; then
            print_success "CloudFront distribution is deployed"
        else
            print_warning "CloudFront status: $CF_STATUS"
        fi
    else
        print_warning "No CloudFront distributions found"
    fi
}

# Check Secrets Manager
check_secrets() {
    print_header "AWS Secrets Manager"
    
    SECRETS=$(aws secretsmanager list-secrets --query 'SecretList[*].[Name,Description]' --output table 2>/dev/null || echo "")
    
    if [ ! -z "$SECRETS" ]; then
        echo "$SECRETS"
        print_success "Secrets Manager is configured"
    else
        print_warning "No secrets found in Secrets Manager"
    fi
}

# Test application connectivity
test_application() {
    print_header "Application Connectivity Test"
    
    if [ ! -z "$CLOUDFRONT_URL" ] && [ "$CLOUDFRONT_URL" != "Not available" ]; then
        print_status "Testing CloudFront URL: $CLOUDFRONT_URL"
        
        if curl -s --head "$CLOUDFRONT_URL" | head -n 1 | grep -q "200 OK"; then
            print_success "Application is accessible via CloudFront"
        else
            print_warning "Application may not be accessible via CloudFront"
            print_status "Response: $(curl -s --head "$CLOUDFRONT_URL" | head -n 1)"
        fi
    else
        print_warning "CloudFront URL not available for testing"
    fi
    
    if [ ! -z "$ALB_URL" ] && [ "$ALB_URL" != "Not available" ]; then
        print_status "Testing ALB URL: $ALB_URL"
        
        if curl -s --head "$ALB_URL" | head -n 1 | grep -q "200 OK"; then
            print_success "Application is accessible via ALB"
        else
            print_warning "Application may not be accessible via ALB"
            print_status "Response: $(curl -s --head "$ALB_URL" | head -n 1)"
        fi
    else
        print_warning "ALB URL not available for testing"
    fi
}

# Main verification function
verify_deployment() {
    print_header "AWS Deployment Verification"
    print_status "Starting comprehensive AWS resource verification..."
    echo ""
    
    check_aws_config
    echo ""
    
    check_terraform_state
    echo ""
    
    check_ecr
    echo ""
    
    check_ec2
    echo ""
    
    check_asg
    echo ""
    
    check_alb
    echo ""
    
    check_rds
    echo ""
    
    check_cloudfront
    echo ""
    
    check_secrets
    echo ""
    
    test_application
    echo ""
    
    print_header "Verification Complete"
    print_success "AWS deployment verification completed!"
    print_status "Check the results above for any warnings or errors."
}

# Help function
show_help() {
    echo "AWS Deployment Verification Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -a, --aws      Check AWS CLI configuration only"
    echo "  -t, --terraform Check Terraform state only"
    echo "  -e, --ec2      Check EC2 instances only"
    echo "  -r, --rds      Check RDS database only"
    echo "  -c, --cloudfront Check CloudFront only"
    echo "  -u, --url      Test application URLs only"
    echo ""
    echo "This script verifies that all AWS resources are properly deployed and working."
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -a|--aws)
        check_aws_config
        exit 0
        ;;
    -t|--terraform)
        check_terraform_state
        exit 0
        ;;
    -e|--ec2)
        check_ec2
        exit 0
        ;;
    -r|--rds)
        check_rds
        exit 0
        ;;
    -c|--cloudfront)
        check_cloudfront
        exit 0
        ;;
    -u|--url)
        test_application
        exit 0
        ;;
    "")
        verify_deployment
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
