output "role_name" {
  value       = aws_iam_role.dev.name
  description = "Developer role name"
}

output "role_arn" {
  value       = aws_iam_role.dev.arn
  description = "Developer role ARN"
}
