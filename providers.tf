terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.40"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  profile                     = var.aws_profile
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  default_tags {
    tags = local.tags
  }
}
