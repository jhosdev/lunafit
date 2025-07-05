#!/bin/bash

# Deploy script for Lunafit
set -e

echo "🚀 Deploying Lunafit..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not installed. Please install Terraform first."
    exit 1
fi

# Build Lambda functions
echo "📦 Building Lambda functions..."
./scripts/build.sh

# Deploy infrastructure
echo "🏗️  Deploying infrastructure..."
cd infra

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Plan the deployment
echo "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply the deployment
echo "Applying Terraform deployment..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo "✅ Infrastructure deployed successfully!"

# Get outputs
echo "📋 Deployment outputs:"
terraform output

cd ..

echo "🎉 Lunafit deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Test the API endpoints"
echo "2. Monitor CloudWatch logs"
echo "3. Set up monitoring and alerting" 