variable "name" {
  description = "Name prefix for the Grafana ECS cluster, service, ALB, and supporting resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region used for log groups, CloudWatch, and X-Ray queries."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used in KMS key policies."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that hosts the Grafana ALB and ECS service."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets used by the Grafana ALB and Fargate tasks."
  type        = list(string)
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the Grafana ALB on port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_ingress_cidrs) > 0
    error_message = "allowed_ingress_cidrs must contain at least one CIDR block."
  }
}

variable "image_uri" {
  description = "Private ECR image URI for the OSS Grafana container."
  type        = string
}

variable "task_cpu" {
  description = "Fargate CPU units for the Grafana task."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate memory in MiB for the Grafana task."
  type        = number
  default     = 1024
}

variable "cpu_architecture" {
  description = "Task definition CPU architecture."
  type        = string
  default     = "X86_64"
}

variable "log_retention_days" {
  description = "Retention applied to the Grafana CloudWatch log group."
  type        = number
  default     = 30
}

variable "kms_key_deletion_window_in_days" {
  description = "Deletion window for the Grafana logs customer managed KMS key."
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Protect the Grafana ALB from accidental deletion."
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "SNS topic notified by the Grafana ALB healthy-target alarm."
  type        = string
}

variable "app_log_group_name" {
  description = "CloudWatch log group used by the application — preselected as the default CloudWatch Logs source."
  type        = string
}

variable "app_cluster_name" {
  description = "Application ECS cluster name. Used as a dashboard variable so panels resolve without manual selection."
  type        = string
}

variable "app_service_name" {
  description = "Application ECS service name. Used as a dashboard variable."
  type        = string
}

variable "app_alb_arn_suffix" {
  description = "Application ALB ARN suffix. Used by the SLA dashboard CloudWatch queries."
  type        = string
}

variable "app_target_group_arn_suffix" {
  description = "Application ALB target group ARN suffix. Used by the SLA dashboard CloudWatch queries."
  type        = string
}

variable "tags" {
  description = "Tags applied to all Grafana resources."
  type        = map(string)
  default     = {}
}
