output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "application_log_group_name" {
  description = "CloudWatch Logs group that receives the duplicated structured application logs."
  value       = aws_cloudwatch_log_group.application.name
}

output "alb_dns_name" {
  description = "Internet-facing ALB DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch dashboard queries."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch dashboard queries."
  value       = aws_lb_target_group.this.arn_suffix
}

output "task_role_arn" {
  description = "Task role ARN used by FireLens and X-Ray."
  value       = aws_iam_role.task.arn
}

