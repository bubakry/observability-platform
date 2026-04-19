output "vpc_id" {
  description = "Shared VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block assigned to the VPC."
  value       = var.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnets used by the ALB."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnets used by ECS and OpenSearch."
  value       = module.vpc.private_subnets
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks."
  value       = local.public_subnets
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks."
  value       = local.private_subnets
}

