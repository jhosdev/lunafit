use lambda_http::{Body, Error, Request, Response};
use serde::{Deserialize, Serialize};
use aws_sdk_cognitoidentityprovider::Client as CognitoClient;
use aws_config::load_defaults;
use tracing::{info, error};
use uuid::Uuid;

#[derive(Deserialize)]
struct RegisterUserRequest {
    email: String,
    password: String,
    tenant_id: String,
    user_role: Option<String>,
}

#[derive(Serialize)]
struct RegisterUserResponse {
    user_id: String,
    message: String,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
    message: String,
}

pub(crate) async fn function_handler(event: Request) -> Result<Response<Body>, Error> {
    info!("Processing user registration request");

    // Parse the request body
    let body = event.body();
    let request: RegisterUserRequest = match serde_json::from_slice(body) {
        Ok(req) => req,
        Err(e) => {
            error!("Invalid request body: {}", e);
            return Ok(create_error_response(400, "INVALID_REQUEST", "Invalid request body"));
        }
    };

    // Validate input
    if request.email.is_empty() || request.password.is_empty() || request.tenant_id.is_empty() {
        return Ok(create_error_response(400, "VALIDATION_ERROR", "Email, password, and tenant_id are required"));
    }

    // Validate email format
    if !request.email.contains('@') {
        return Ok(create_error_response(400, "VALIDATION_ERROR", "Invalid email format"));
    }

    // Validate password strength (basic)
    if request.password.len() < 8 {
        return Ok(create_error_response(400, "VALIDATION_ERROR", "Password must be at least 8 characters long"));
    }

    // Initialize AWS Cognito client
    let config = load_defaults(aws_config::BehaviorVersion::latest()).await;
    let cognito_client = CognitoClient::new(&config);

    // Get user pool ID from environment
    let user_pool_id = std::env::var("USER_POOL_ID")
        .map_err(|_| "USER_POOL_ID environment variable not set")?;

    // Generate user ID
    let user_id = Uuid::new_v4().to_string();

    // Create user in Cognito
    match register_user_in_cognito(
        &cognito_client,
        &user_pool_id,
        &user_id,
        &request.email,
        &request.password,
        &request.tenant_id,
        &request.user_role.unwrap_or_else(|| "User".to_string()),
    ).await {
        Ok(_) => {
            info!("User registered successfully: {}", user_id);
            Ok(create_success_response(RegisterUserResponse {
                user_id,
                message: "User registered successfully. Please check your email for verification.".to_string(),
            }))
        }
        Err(e) => {
            error!("Failed to register user: {}", e);
            Ok(create_error_response(500, "REGISTRATION_FAILED", &e.to_string()))
        }
    }
}

async fn register_user_in_cognito(
    client: &CognitoClient,
    user_pool_id: &str,
    user_id: &str,
    email: &str,
    password: &str,
    tenant_id: &str,
    user_role: &str,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    use aws_sdk_cognitoidentityprovider::types::{AttributeType, DeliveryMediumType};

    let result = client
        .admin_create_user()
        .user_pool_id(user_pool_id)
        .username(user_id)
        .user_attributes(
            AttributeType::builder()
                .name("email")
                .value(email)
                .build()?,
        )
        .user_attributes(
            AttributeType::builder()
                .name("email_verified")
                .value("false")
                .build()?,
        )
        .user_attributes(
            AttributeType::builder()
                .name("custom:tenant_id")
                .value(tenant_id)
                .build()?,
        )
        .user_attributes(
            AttributeType::builder()
                .name("custom:user_role")
                .value(user_role)
                .build()?,
        )
        .desired_delivery_mediums(DeliveryMediumType::Email)
        .temporary_password(password)
        .message_action(aws_sdk_cognitoidentityprovider::types::MessageActionType::Suppress)
        .send()
        .await?;

    info!("User created in Cognito: {:?}", result.user);

    // Set permanent password
    client
        .admin_set_user_password()
        .user_pool_id(user_pool_id)
        .username(user_id)
        .password(password)
        .permanent(true)
        .send()
        .await?;

    info!("Password set for user: {}", user_id);

    Ok(())
}

fn create_success_response<T: Serialize>(data: T) -> Response<Body> {
    Response::builder()
        .status(201)
        .header("content-type", "application/json")
        .body(serde_json::to_string(&data).unwrap().into())
        .unwrap()
}

fn create_error_response(status: u16, error_code: &str, message: &str) -> Response<Body> {
    let error_response = ErrorResponse {
        error: error_code.to_string(),
        message: message.to_string(),
    };

    Response::builder()
        .status(status)
        .header("content-type", "application/json")
        .body(serde_json::to_string(&error_response).unwrap().into())
        .unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;
    use lambda_http::Request;

    #[tokio::test]
    async fn test_invalid_request_body() {
        let request = Request::new(Body::Empty);
        let response = function_handler(request).await.unwrap();
        assert_eq!(response.status(), 400);
    }

    #[tokio::test]
    async fn test_missing_required_fields() {
        let body = r#"{"email": "", "password": "", "tenant_id": ""}"#;
        let request = Request::new(body.into());
        
        let response = function_handler(request).await.unwrap();
        assert_eq!(response.status(), 400);
    }

    #[tokio::test]
    async fn test_invalid_email_format() {
        let body = r#"{"email": "invalid-email", "password": "password123", "tenant_id": "tenant1"}"#;
        let request = Request::new(body.into());
        
        let response = function_handler(request).await.unwrap();
        assert_eq!(response.status(), 400);
    }

    #[tokio::test]
    async fn test_password_too_short() {
        let body = r#"{"email": "test@example.com", "password": "short", "tenant_id": "tenant1"}"#;
        let request = Request::new(body.into());
        
        let response = function_handler(request).await.unwrap();
        assert_eq!(response.status(), 400);
    }
}
