output "rds_endpoint" {
  description = "RDS Postgres endpoint (host:port) - reachable only from inside the VPC (i.e. from Lambda, not from your machine)."
  value       = aws_db_instance.main.endpoint
}

output "api_lambda_function_name" {
  description = "The function API Gateway's integration points at."
  value       = aws_lambda_function.api.function_name
}

output "migrate_lambda_function_name" {
  description = "Invoke this manually after any deploy that changes the schema: aws lambda invoke --function-name <this> --cli-binary-format raw-in-base64-out /dev/stdout"
  value       = aws_lambda_function.migrate.function_name
}

output "api_url" {
  description = "The API's real public HTTPS URL."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "frontend_bucket_name" {
  description = "Sync the built frontend here: aws s3 sync dist/ s3://<this>/"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_url" {
  description = "The live site."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "Needed to invalidate the CDN cache after deploying new frontend files: aws cloudfront create-invalidation --distribution-id <this> --paths '/*'"
  value       = aws_cloudfront_distribution.frontend.id
}
