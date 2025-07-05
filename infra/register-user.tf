resource "aws_iam_user" "lambda-register-user" {
  name = "lambda-register-user"
}

resource "aws_iam_access_key" "lambda-register-user" {
  user = aws_iam_user.lambda-register-user.name
}

resource "aws_iam_policy" "lambda-service-policy" {
  name   = "lambda-service-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetLayerVersion",
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:TagResource"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:register-user",
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "lambda-service-user-policy-attachment" {
  user       = aws_iam_user.lambda-register-user.name
  policy_arn = aws_iam_policy.lambda-service-policy.arn
}

output "aws_access_key_id" {
  value = aws_iam_access_key.lambda-register-user.id
}

output "aws_secret_access_key" {
  value     = aws_iam_access_key.lambda-register-user.secret
  sensitive = true
}