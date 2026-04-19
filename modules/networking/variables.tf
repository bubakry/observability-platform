variable "name" {
  description = "Name prefix for the VPC and endpoints."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones used by the VPC."
  type        = number
}

variable "tags" {
  description = "Tags applied to networking resources."
  type        = map(string)
  default     = {}
}

