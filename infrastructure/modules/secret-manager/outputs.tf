output "SECRET_ARN" {
  value = aws_secretsmanager_secret.secret_manager.arn
}


output "SECRET_ID" {
  value = aws_secretsmanager_secret.secret_manager.id
}