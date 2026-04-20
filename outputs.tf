output "application_url" {
  description = "Public URL for the FastAPI sample application fronted by the ALB."
  value       = module.ecs_app.application_url
}

output "alb_https_enabled" {
  description = "Whether the application load balancer is serving HTTPS."
  value       = module.ecs_app.alb_https_enabled
}

output "grafana_url" {
  description = "Public URL for the self-hosted Grafana workspace."
  value       = module.grafana.grafana_url
}

output "grafana_admin_secret_name" {
  description = "Secrets Manager secret name that holds the Grafana admin password. Read with: aws secretsmanager get-secret-value --secret-id <name> --query SecretString --output text"
  value       = module.grafana.admin_secret_name
}

output "alarm_sns_topic_arn" {
  description = "SNS topic targeted by all CloudWatch alarms."
  value       = aws_sns_topic.alerts.arn
}

output "ecr_repositories" {
  description = "Private ECR repositories that hold the application and sidecar images."
  value = {
    app      = module.ecr_build.app_repository_url
    firelens = module.ecr_build.firelens_repository_url
    xray     = module.ecr_build.xray_repository_url
    grafana  = module.ecr_build.grafana_repository_url
  }
}
