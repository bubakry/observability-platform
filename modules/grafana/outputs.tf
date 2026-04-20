output "grafana_url" {
  description = "Public URL for the OSS Grafana workspace."
  value       = "http://${aws_lb.this.dns_name}"
}

output "alb_dns_name" {
  description = "Grafana ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "admin_secret_arn" {
  description = "Secrets Manager ARN holding the Grafana admin password."
  value       = aws_secretsmanager_secret.admin.arn
}

output "admin_secret_name" {
  description = "Secrets Manager secret name holding the Grafana admin password."
  value       = aws_secretsmanager_secret.admin.name
}

output "cluster_name" {
  description = "ECS cluster name running Grafana."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name running Grafana."
  value       = aws_ecs_service.this.name
}

output "log_group_name" {
  description = "CloudWatch log group receiving Grafana container logs."
  value       = aws_cloudwatch_log_group.this.name
}
