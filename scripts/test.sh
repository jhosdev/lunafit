#!/bin/bash

# Test script for Lunafit API
set -e

echo "🧪 Testing Lunafit API..."

# Get API Gateway URL from Terraform output
cd infra
API_URL=$(terraform output -raw api_gateway_url)
cd ..

if [ -z "$API_URL" ]; then
    echo "❌ Could not get API Gateway URL from Terraform output"
    exit 1
fi

echo "🌐 API URL: $API_URL"

# Test data
TEST_EMAIL="test@example.com"
TEST_PASSWORD="TempPassword123!"
TEST_TENANT_ID="tenant-001"

echo ""
echo "1️⃣ Testing user registration..."

REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"$TEST_PASSWORD\",
        \"tenant_id\": \"$TEST_TENANT_ID\",
        \"user_role\": \"User\"
    }")

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration was successful
if echo "$REGISTER_RESPONSE" | jq -e '.success' > /dev/null; then
    echo "✅ User registration successful"
    USER_ID=$(echo "$REGISTER_RESPONSE" | jq -r '.data.user_id')
    echo "User ID: $USER_ID"
else
    echo "❌ User registration failed"
    echo "Response: $REGISTER_RESPONSE"
    exit 1
fi

echo ""
echo "2️⃣ Testing user confirmation..."
echo "⚠️  Note: You'll need to get the confirmation code from your email or Cognito console"
echo "Example confirmation request:"
echo "curl -X POST \"$API_URL/auth/confirm\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"email\": \"$TEST_EMAIL\","
echo "    \"confirmation_code\": \"123456\""
echo "  }'"

echo ""
echo "3️⃣ Testing authentication (after confirmation)..."
echo "Example authentication request:"
echo "curl -X POST \"$API_URL/auth/login\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"email\": \"$TEST_EMAIL\","
echo "    \"password\": \"$TEST_PASSWORD\""
echo "  }'"

echo ""
echo "🎉 Basic API tests completed!"
echo ""
echo "Manual testing steps:"
echo "1. Check your email for confirmation code"
echo "2. Use the confirmation endpoint to confirm the user"
echo "3. Use the login endpoint to authenticate"
echo "4. Check CloudWatch logs for detailed execution traces"
echo "5. Verify DynamoDB tables have the expected data" 