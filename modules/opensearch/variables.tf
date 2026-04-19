variable "domain_name" {
  description = "Name of the OpenSearch domain."
  type        = string
}

variable "engine_version" {
  description = "OpenSearch engine version."
  type        = string
}

variable "instance_type" {
  description = "OpenSearch instance type."
  type        = string
}

variable "instance_count" {
  description = "Number of OpenSearch data nodes."
  type        = number
}

variable "ebs_volume_size" {
  description = "gp3 EBS volume size in GiB."
  type        = number
}

variable "vpc_id" {
  description = "VPC ID hosting the domain."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used in the OpenSearch KMS key policy."
  type        = string
}

variable "aws_region" {
  description = "AWS region hosting the OpenSearch domain."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the domain."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the private domain over HTTPS."
  type        = list(string)
}

variable "create_service_linked_role" {
  description = "Whether to create the OpenSearch service-linked role. Leave false when the account already has it (the common case)."
  type        = bool
  default     = false
}

variable "availability_zone_count" {
  description = "Number of Availability Zones used by the domain."
  type        = number
  default     = 2
}

variable "dedicated_master_enabled" {
  description = "Whether to use dedicated master nodes for the domain."
  type        = bool
  default     = true
}

variable "dedicated_master_count" {
  description = "Number of dedicated master nodes when enabled."
  type        = number
  default     = 3
}

variable "dedicated_master_type" {
  description = "Instance type used for dedicated master nodes."
  type        = string
  default     = "t3.small.search"
}

variable "kms_key_deletion_window_in_days" {
  description = "Deletion window for the OpenSearch customer managed KMS key."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to OpenSearch resources."
  type        = map(string)
  default     = {}
}
