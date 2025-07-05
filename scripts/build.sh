#!/bin/bash

# Build script for Lunafit Lambda functions
set -e

echo "🚀 Building Lunafit Lambda functions..."

# Change to the backend directory
cd apps/backend

# List of Lambda functions to build
LAMBDAS=(
    "identity-register-user"
    "identity-authenticate-user"
    "identity-confirm-registration"
    "identity-pre-signup"
    "identity-event-processor"
    "api-authorizer"
)

# Create build directory if it doesn't exist
mkdir -p ../../build/lambdas

echo "📦 Installing cargo-lambda if not present..."
if ! command -v cargo-lambda &> /dev/null; then
    echo "Installing cargo-lambda..."
    pip install cargo-lambda
fi

# Build each Lambda function
for lambda in "${LAMBDAS[@]}"; do
    echo "🔨 Building $lambda..."
    
    # Build the Lambda function
    cargo lambda build --release --lambda-dir lambdas/$lambda --output-format zip
    
    # Move the zip file to the build directory
    if [ -f "target/lambda/$lambda/bootstrap.zip" ]; then
        cp "target/lambda/$lambda/bootstrap.zip" "../../build/lambdas/$lambda.zip"
        echo "✅ Built $lambda -> build/lambdas/$lambda.zip"
    else
        echo "❌ Failed to build $lambda"
        exit 1
    fi
done

echo "🎉 All Lambda functions built successfully!"
echo "📁 Build artifacts available in: build/lambdas/"
echo ""
echo "Next steps:"
echo "1. Deploy infrastructure: cd infra && terraform apply"
echo "2. Upload Lambda functions using the generated zip files" 