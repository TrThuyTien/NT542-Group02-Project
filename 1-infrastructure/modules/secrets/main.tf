resource "aws_kms_key" "kms_key" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "kms_alias" {
  depends_on    = [aws_kms_key.kms_key]
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.kms_key.id
}

resource "aws_secretsmanager_secret" "secret" {
  depends_on = [aws_kms_key.kms_key]
  name       = var.secret_name
  kms_key_id = aws_kms_key.kms_key.arn
}

resource "aws_secretsmanager_secret_version" "this" {
  depends_on    = [aws_secretsmanager_secret.secret]
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = var.secret_string_json
}