# Cognito User Pool for Identity Domain
resource "aws_cognito_user_pool" "lunafit_user_pool" {
  name = "lunafit-user-pool"

  # Custom attributes for multi-tenancy
  schema {
    attribute_data_type = "String"
    name                = "tenant_id"
    mutable             = true
    required            = false
    
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    attribute_data_type = "String"
    name                = "user_role"
    mutable             = true
    required            = false
    
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Email configuration
  auto_verified_attributes = ["email"]
  
  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email verification
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_message        = "Your verification code is {####}"
    email_subject        = "Lunafit - Verify your email"
  }

  tags = {
    Name        = "lunafit-user-pool"
    Environment = var.environment
    Domain      = "identity"
  }
}

# User Pool Client
resource "aws_cognito_user_pool_client" "lunafit_user_pool_client" {
  name         = "lunafit-user-pool-client"
  user_pool_id = aws_cognito_user_pool.lunafit_user_pool.id

  # Auth flows
  explicit_auth_flows = [
    "ADMIN_NO_SRP_AUTH",
    "USER_PASSWORD_AUTH"
  ]
  
  # Enable refresh token auth separately
  generate_secret = false

  # Token validity
  access_token_validity  = 60    # 1 hour
  id_token_validity      = 60    # 1 hour
  refresh_token_validity = 30    # 30 days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read and write attributes
  read_attributes = [
    "email",
    "email_verified",
    "custom:tenant_id",
    "custom:user_role"
  ]

  write_attributes = [
    "email",
    "custom:tenant_id",
    "custom:user_role"
  ]
}

# Outputs
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.lunafit_user_pool.id
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.lunafit_user_pool_client.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.lunafit_user_pool.arn
} 