output "workspace_id" {
  description = "Amazon Managed Grafana workspace ID."
  value       = aws_grafana_workspace.this.id
}

output "workspace_endpoint" {
  description = "Workspace URL used for dashboard provisioning."
  value       = aws_grafana_workspace.this.endpoint
}

output "workspace_role_arn" {
  description = "IAM role ARN used by the managed workspace for AWS integrations."
  value       = aws_grafana_workspace.this.role_arn
}

output "workspace_kms_key_arn" {
  description = "KMS key ARN used to encrypt the Grafana workspace at rest."
  value       = aws_kms_key.workspace.arn
}

output "api_key" {
  description = "Sensitive Grafana API key used for automated provisioning."
  value       = aws_grafana_workspace_api_key.automation.key
  sensitive   = true
}
