resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

# AWS_PROXY + payload_format_version 2.0: forwards the raw HTTP request to
# Lambda as a JSON event (method, path, headers, body), and expects back a
# {"statusCode": ..., "body": ...} shaped response - the format Mangum
# translates to/from FastAPI's ASGI protocol on the Lambda side.
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# Catch-all: every method/path forwards to Lambda. FastAPI does its own
# routing internally (/login, /me, /health) - API Gateway doesn't need to
# know about any of that.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# HTTP APIs need at least one stage to get a live URL. auto_deploy: route
# changes go live without a separate manual "deploy" step.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# Resource-based policy granting API Gateway permission to invoke this
# specific function - without it, API Gateway calling Lambda's Invoke API
# gets an IAM permission error.
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
