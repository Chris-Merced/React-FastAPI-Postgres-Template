resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

locals {
  # Assembled here, not typed anywhere - matches the RDS instance's real
  # address plus the generated password from rds.tf.
  database_url = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"

  # Built by scripts/build-backend.ps1 - must exist before `terraform
  # apply` runs (same bootstrap-order requirement the old ECR-image
  # approach had: a Lambda function can't be created pointing at code
  # that doesn't exist yet either way).
  lambda_zip_path = "${path.module}/../backend/lambda.zip"
}

# Explicit log groups with real retention - without this, Lambda
# auto-creates its own log group on first invoke with NO retention limit,
# so logs (and their storage cost) accumulate forever by default.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${var.project_name}-api"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "migrate" {
  name              = "/aws/lambda/${var.project_name}-migrate"
  retention_in_days = 7
}

# The function API Gateway calls.
resource "aws_lambda_function" "api" {
  function_name    = "${var.project_name}-api"
  role             = aws_iam_role.lambda.arn
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  handler          = "lambda_handler.handler"
  runtime          = "python3.13"
  timeout          = 15
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATABASE_URL    = local.database_url
      JWT_SECRET      = random_password.jwt_secret.result
      ALLOWED_ORIGINS = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.api,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
  ]
}

# Same zip, different handler - runs `alembic upgrade head` (and,
# optionally, seed.py) against RDS. Never wired to API Gateway; invoked
# manually via `aws lambda invoke` (see README.md) after each deploy that changes the
# schema. See backend/lambda_migrate.py.
resource "aws_lambda_function" "migrate" {
  function_name    = "${var.project_name}-migrate"
  role             = aws_iam_role.lambda.arn
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)
  handler          = "lambda_migrate.handler"
  runtime          = "python3.13"
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DATABASE_URL = local.database_url
      # Not actually used by lambda_migrate.py - but alembic/env.py imports
      # config.py, which requires this at import time with no default (see
      # backend/config.py). Cheaper to supply it than to restructure that.
      JWT_SECRET = random_password.jwt_secret.result
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.migrate,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
  ]
}
