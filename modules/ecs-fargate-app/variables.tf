variable "name" {
  description = "Name prefix for the ECS cluster, service, and supporting resources."
  type        = string
}

variable "environment" {
  description = "Environment label exposed to the application."
  type        = string
}

variable "aws_region" {
  description = "AWS region for logs, metrics, and X-Ray."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used in KMS key policies."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that hosts the load balancer and ECS tasks."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets used by the internet-facing ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets used by the ECS service."
  type        = list(string)
}

variable "app_image_uri" {
  description = "Private ECR image URI for the FastAPI service."
  type        = string
}

variable "firelens_image_uri" {
  description = "Private ECR image URI for the custom FireLens router."
  type        = string
}

variable "xray_image_uri" {
  description = "Private ECR image URI for the mirrored X-Ray daemon."
  type        = string
}

variable "app_port" {
  description = "Port exposed by the FastAPI container."
  type        = number
}

variable "app_cpu" {
  description = "Fargate CPU units for the task definition."
  type        = number
}

variable "app_memory" {
  description = "Fargate memory in MiB for the task definition."
  type        = number
}

variable "desired_count" {
  description = "Number of ECS tasks kept in service."
  type        = number
}

variable "cpu_architecture" {
  description = "Task definition CPU architecture."
  type        = string
}

variable "task_role_name" {
  description = "Explicit task role name to keep IAM naming predictable."
  type        = string
}

variable "execution_role_name" {
  description = "Explicit task execution role name."
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic notified by all CloudWatch alarms."
  type        = string
}

variable "allowed_alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the public ALB on port 80."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_certificate_arn" {
  description = "Optional ACM certificate ARN for HTTPS. When set, port 80 redirects to 443."
  type        = string
  default     = null
  nullable    = true
}

variable "alb_ssl_policy" {
  description = "SSL policy used by the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "enable_alb_deletion_protection" {
  description = "Protect the ALB from accidental deletion."
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum ECS service desired count."
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum ECS service desired count."
  type        = number
  default     = 6
}

variable "autoscaling_cpu_target" {
  description = "Target average CPU utilization for ECS service autoscaling."
  type        = number
  default     = 60
}

variable "autoscaling_memory_target" {
  description = "Target average memory utilization for ECS service autoscaling."
  type        = number
  default     = 70
}

variable "log_retention_days" {
  description = "Retention applied to all CloudWatch log groups."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to ECS and related resources."
  type        = map(string)
  default     = {}
}
