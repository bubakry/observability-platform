output "application_url" {
  description = "Public URL for the FastAPI sample application fronted by the ALB."
  value       = module.ecs_app.application_url
}

output "alb_https_enabled" {
  description = "Whether the application load balancer is serving HTTPS."
  value       = module.ecs_app.alb_https_enabled
}

output "grafana_workspace_url" {
  description = "Amazon Managed Grafana workspace URL."
  value       = module.grafana.workspace_endpoint
}

output "opensearch_endpoint" {
  description = "Private OpenSearch endpoint used by FireLens for structured log ingestion."
  value       = module.opensearch.domain_endpoint
}

output "opensearch_dashboards_endpoint" {
  description = "Private OpenSearch Dashboards endpoint."
  value       = module.opensearch.dashboard_endpoint
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
  }
}
