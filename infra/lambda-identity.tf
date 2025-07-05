# IAM Role for Identity Register User Lambda
resource "aws_iam_role" "identity_register_user_role" {
  name = "lunafit-identity-register-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "lunafit-identity-register-user-role"
    Environment = var.environment
    Domain      = "identity"
  }
}

# IAM Policy for Identity Register User Lambda
resource "aws_iam_role_policy" "identity_register_user_policy" {
  name = "lunafit-identity-register-user-policy"
  role = aws_iam_role.identity_register_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminSetUserPassword",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminUpdateUserAttributes"
        ]
        Resource = aws_cognito_user_pool.lunafit_user_pool.arn
      }
    ]
  })
}

# Lambda Function for Identity Register User
resource "aws_lambda_function" "identity_register_user" {
  filename         = "../build/register-user.zip"
  function_name    = "lunafit-identity-register-user"
  role            = aws_iam_role.identity_register_user_role.arn
  handler         = "bootstrap"
  runtime         = "provided.al2"
  architectures   = ["arm64"]
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.lunafit_user_pool.id
      RUST_LOG     = "info"
    }
  }

  depends_on = [
    aws_iam_role_policy.identity_register_user_policy,
    aws_cloudwatch_log_group.identity_register_user_logs
  ]

  tags = {
    Name        = "lunafit-identity-register-user"
    Environment = var.environment
    Domain      = "identity"
  }
}

# CloudWatch Log Group for Identity Register User Lambda
resource "aws_cloudwatch_log_group" "identity_register_user_logs" {
  name              = "/aws/lambda/lunafit-identity-register-user"
  retention_in_days = 14

  tags = {
    Name        = "lunafit-identity-register-user-logs"
    Environment = var.environment
    Domain      = "identity"
  }
}

# API Gateway Integration (will be created later)
# For now, we'll just output the function ARN
output "identity_register_user_function_arn" {
  description = "ARN of the Identity Register User Lambda function"
  value       = aws_lambda_function.identity_register_user.arn
}

output "identity_register_user_function_name" {
  description = "Name of the Identity Register User Lambda function"
  value       = aws_lambda_function.identity_register_user.function_name
} 