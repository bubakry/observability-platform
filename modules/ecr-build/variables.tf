variable "name" {
  description = "Name prefix for the private ECR repositories."
  type        = string
}

variable "aws_region" {
  description = "Region used for the ECR login command."
  type        = string
}

variable "image_platform" {
  description = "Docker buildx platform, such as linux/amd64 or linux/arm64."
  type        = string
}

variable "app_source_path" {
  description = "Path to the FastAPI application Docker build context."
  type        = string
}

variable "firelens_source_path" {
  description = "Path to the FireLens custom image Docker build context."
  type        = string
}

variable "xray_source_path" {
  description = "Path to the mirrored X-Ray daemon Docker build context."
  type        = string
}

variable "grafana_source_path" {
  description = "Path to the OSS Grafana Docker build context."
  type        = string
}

variable "app_image_tag" {
  description = "Optional override for the application image tag. When null the tag is derived from the build context hash so each change produces a unique, immutable tag."
  type        = string
  default     = null
  nullable    = true
}

variable "firelens_image_tag" {
  description = "Optional override for the FireLens image tag. When null the tag is derived from the build context hash."
  type        = string
  default     = null
  nullable    = true
}

variable "xray_image_tag" {
  description = "Optional override for the X-Ray daemon image tag. When null the tag is derived from the build context hash."
  type        = string
  default     = null
  nullable    = true
}

variable "grafana_image_tag" {
  description = "Optional override for the Grafana image tag. When null the tag is derived from the build context hash."
  type        = string
  default     = null
  nullable    = true
}

variable "image_tag_mutability" {
  description = "ECR image tag mutability for all repositories."
  type        = string
  default     = "IMMUTABLE"
}

variable "force_delete" {
  description = "Allow terraform destroy to remove repositories that still contain images."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to ECR repositories."
  type        = map(string)
  default     = {}
}

