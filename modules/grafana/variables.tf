variable "name" {
  description = "Managed Grafana workspace name."
  type        = string
}

variable "description" {
  description = "Workspace description."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used in the Grafana KMS key policy."
  type        = string
}

variable "aws_region" {
  description = "AWS region that hosts the Grafana workspace."
  type        = string
}

variable "grafana_version" {
  description = "Amazon Managed Grafana version."
  type        = string
}

variable "api_key_ttl_seconds" {
  description = "Lifetime of the API key used for automated provisioning."
  type        = number
}

variable "admin_user_ids" {
  description = "Optional IAM Identity Center users granted Grafana admin access."
  type        = list(string)
  default     = []
}

variable "admin_group_ids" {
  description = "Optional IAM Identity Center groups granted Grafana admin access."
  type        = list(string)
  default     = []
}

variable "kms_key_deletion_window_in_days" {
  description = "Deletion window for the Grafana customer managed KMS key."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to the Grafana workspace."
  type        = map(string)
  default     = {}
}
