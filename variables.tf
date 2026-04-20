variable "aws_region" {
  description = "AWS region that hosts the entire observability platform."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID used to protect applies from running in the wrong account. Required."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "alb_certificate_arn" {
  description = "Optional ACM certificate ARN for HTTPS on the application load balancer. When set, port 80 redirects to 443."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_profile" {
  description = "Named AWS CLI profile used by the provider. Leave null to fall back to the default credential resolution chain (env vars, instance profile, default profile)."
  type        = string
  default     = null
  nullable    = true
}

variable "project_name" {
  description = "Base project name used for resource naming."
  type        = string
  default     = "aws-enterprise-observability"
}

variable "environment" {
  description = "Environment label used for naming and tagging."
  type        = string
  default     = "portfolio"
}

variable "vpc_cidr" {
  description = "CIDR block for the shared observability VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of Availability Zones used by the VPC and ECS service."
  type        = number
  default     = 2
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks to keep running behind the ALB."
  type        = number
  default     = 2
}

variable "ecs_autoscaling_min_capacity" {
  description = "Minimum desired count maintained by ECS service autoscaling."
  type        = number
  default     = 2
}

variable "ecs_autoscaling_max_capacity" {
  description = "Maximum desired count maintained by ECS service autoscaling."
  type        = number
  default     = 6
}

variable "ecs_autoscaling_cpu_target" {
  description = "Target average ECS CPU utilization for scaling."
  type        = number
  default     = 60
}

variable "ecs_autoscaling_memory_target" {
  description = "Target average ECS memory utilization for scaling."
  type        = number
  default     = 70
}

variable "app_port" {
  description = "Container port exposed by the FastAPI application."
  type        = number
  default     = 8000
}

variable "app_cpu" {
  description = "Fargate CPU units for the task definition."
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "Fargate memory in MiB for the task definition."
  type        = number
  default     = 512
}

variable "grafana_kms_key_deletion_window_in_days" {
  description = "Deletion window for the Grafana logs customer managed KMS key."
  type        = number
  default     = 30
}

variable "grafana_allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the public Grafana ALB on port 80. Lock this down for non-portfolio deployments."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.grafana_allowed_ingress_cidrs) > 0
    error_message = "grafana_allowed_ingress_cidrs must contain at least one CIDR block."
  }
}

variable "alarm_email" {
  description = "Optional email address subscribed to the SNS topic for CloudWatch alarms."
  type        = string
  default     = ""

  validation {
    condition     = var.alarm_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alarm_email))
    error_message = "alarm_email must be empty or a valid email address."
  }
}

variable "allowed_alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the public ALB on port 80. Lock this down to known networks for non-portfolio deployments."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_alb_ingress_cidrs) > 0
    error_message = "allowed_alb_ingress_cidrs must contain at least one CIDR block."
  }
}

variable "ecr_image_tag_mutability" {
  description = "ECR image tag mutability for app, FireLens, and X-Ray repositories."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "ecr_force_delete" {
  description = "Allow terraform destroy to remove ECR repositories even when images are present. Keep false in production."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention applied to all CloudWatch log groups."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch-supported retention value."
  }
}

variable "enable_alb_deletion_protection" {
  description = "Protect the ALB from accidental deletion. Recommended true in production."
  type        = bool
  default     = true
}

variable "owner" {
  description = "Owner tag applied to all resources. Supplied via TF_VAR_owner so it never lives in source."
  type        = string
  default     = ""
}

variable "cost_center" {
  description = "Cost center tag applied to all resources. Supplied via TF_VAR_cost_center so it never lives in source."
  type        = string
  default     = ""
}

variable "container_platform" {
  description = "Docker build platform used when publishing the private ECR images."
  type        = string
  default     = "linux/amd64"
}

variable "container_cpu_architecture" {
  description = "CPU architecture used by the ECS task definition."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.container_cpu_architecture)
    error_message = "container_cpu_architecture must be either X86_64 or ARM64."
  }
}

variable "tags" {
  description = "Additional tags merged into all provisioned resources."
  type        = map(string)
  default     = {}
}
