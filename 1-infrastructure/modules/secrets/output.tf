output "secret_arn" {
  value = aws_secretsmanager_secret.secret.arn
}

output "kms_key_arn" {
  value = aws_kms_key.kms_key.arn
}

output "kms_key_id" {
  value = aws_kms_key.kms_key.key_id
}