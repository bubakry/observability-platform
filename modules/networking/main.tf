data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnets  = [for index in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, index)]
  private_subnets = [for index in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, index + 8)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.name
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway = false
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = module.vpc.vpc_id

  create_security_group      = true
  security_group_name_prefix = "${var.name}-vpce-"
  security_group_description = "Shared interface endpoint security group."

  security_group_rules = {
    ingress_https = {
      description = "Allow HTTPS traffic from private subnets to the interface endpoints."
      cidr_blocks = local.private_subnets
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
    }
  }

  endpoints = {
    ecr_api = {
      service             = "ecr.api"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = var.tags
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = var.tags
    }
    logs = {
      service             = "logs"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = var.tags
    }
    xray = {
      service             = "xray"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = var.tags
    }
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = var.tags
    }
  }

  tags = var.tags
}

