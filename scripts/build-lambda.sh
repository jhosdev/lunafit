#!/bin/bash

set -e

echo "🚀 Building Identity Register User Lambda..."

# Change to backend directory
cd apps/backend

# Build the lambda
echo "Building register-user lambda..."
cargo lambda build --release --arm64 --output-format zip

# Create build directory
mkdir -p ../../build

# Copy the zip file
cp target/lambda/register-user/bootstrap.zip ../../build/register-user.zip

echo "✅ Lambda built successfully!"
echo "📦 Build artifact: build/register-user.zip"

# Show file size
echo "📊 File size: $(du -h ../../build/register-user.zip | cut -f1)" 