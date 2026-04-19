output "domain_name" {
  description = "OpenSearch domain name."
  value       = aws_opensearch_domain.this.domain_name
}

output "domain_arn" {
  description = "OpenSearch domain ARN."
  value       = aws_opensearch_domain.this.arn
}

output "domain_endpoint" {
  description = "Private endpoint used for FireLens log ingestion."
  value       = aws_opensearch_domain.this.endpoint
}

output "domain_kms_key_arn" {
  description = "KMS key ARN used to encrypt the OpenSearch domain at rest."
  value       = aws_kms_key.domain.arn
}

output "dashboard_endpoint" {
  description = "Private OpenSearch Dashboards endpoint."
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "security_group_id" {
  description = "Security group protecting the domain."
  value       = aws_security_group.this.id
}
