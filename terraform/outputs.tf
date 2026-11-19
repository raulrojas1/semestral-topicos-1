output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.app["frontend"].repository_url
}

output "ecr_backend_url" {
  value = aws_ecr_repository.app["backend"].repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_names" {
  value = { for k, s in aws_ecs_service.app : k => s.name }
}

output "github_app_role_arn" {
  description = "Variable AWS_APP_ROLE_ARN en GitHub"
  value       = aws_iam_role.github_app.arn
}

output "github_terraform_role_arn" {
  description = "Variable AWS_TERRAFORM_ROLE_ARN en GitHub"
  value       = aws_iam_role.github_terraform.arn
}
