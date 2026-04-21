output "lambda_arn" {
  value = aws_lambda_function.this.arn
}

output "lambda_name" {
  value = aws_lambda_function.this.function_name
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}