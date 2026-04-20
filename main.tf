data "aws_caller_identity" "current" {}

check "aws_account_guard" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
    error_message = "aws_account_id must match the AWS account that Terraform is targeting."
  }
}

locals {
  name               = "${var.project_name}-${var.environment}"
  ecs_task_role_name = "${local.name}-task-role"
  ecs_exec_role_name = "${local.name}-execution-role"

  base_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  identity_tags = merge(
    var.owner == "" ? {} : { Owner = var.owner },
    var.cost_center == "" ? {} : { CostCenter = var.cost_center },
  )

  tags = merge(local.base_tags, local.identity_tags, var.tags)
}

module "networking" {
  source = "./modules/networking"

  name     = local.name
  vpc_cidr = var.vpc_cidr
  az_count = var.availability_zone_count
  tags     = local.tags
}

module "ecr_build" {
  source = "./modules/ecr-build"

  name                 = local.name
  aws_region           = var.aws_region
  image_platform       = var.container_platform
  app_source_path      = "${path.module}/app"
  firelens_source_path = "${path.module}/firelens"
  xray_source_path     = "${path.module}/xray"
  grafana_source_path  = "${path.module}/grafana"
  image_tag_mutability = var.ecr_image_tag_mutability
  force_delete         = var.ecr_force_delete
  tags                 = local.tags
}

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  count = trimspace(var.alarm_email) == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

module "grafana" {
  source = "./modules/grafana"

  name                            = "${local.name}-grafana"
  aws_account_id                  = var.aws_account_id
  aws_region                      = var.aws_region
  vpc_id                          = module.networking.vpc_id
  public_subnet_ids               = module.networking.public_subnet_ids
  allowed_ingress_cidrs           = var.grafana_allowed_ingress_cidrs
  image_uri                       = module.ecr_build.grafana_image_uri
  cpu_architecture                = var.container_cpu_architecture
  log_retention_days              = var.log_retention_days
  kms_key_deletion_window_in_days = var.grafana_kms_key_deletion_window_in_days
  enable_deletion_protection      = var.enable_alb_deletion_protection
  sns_topic_arn                   = aws_sns_topic.alerts.arn
  app_log_group_name              = module.ecs_app.application_log_group_name
  app_cluster_name                = module.ecs_app.cluster_name
  app_service_name                = module.ecs_app.service_name
  app_alb_arn_suffix              = module.ecs_app.alb_arn_suffix
  app_target_group_arn_suffix     = module.ecs_app.target_group_arn_suffix
  tags                            = local.tags
}

module "ecs_app" {
  source = "./modules/ecs-fargate-app"

  name                           = local.name
  environment                    = var.environment
  aws_region                     = var.aws_region
  aws_account_id                 = var.aws_account_id
  vpc_id                         = module.networking.vpc_id
  public_subnet_ids              = module.networking.public_subnet_ids
  private_subnet_ids             = module.networking.private_subnet_ids
  app_image_uri                  = module.ecr_build.app_image_uri
  firelens_image_uri             = module.ecr_build.firelens_image_uri
  xray_image_uri                 = module.ecr_build.xray_image_uri
  app_port                       = var.app_port
  app_cpu                        = var.app_cpu
  app_memory                     = var.app_memory
  desired_count                  = var.ecs_desired_count
  autoscaling_min_capacity       = var.ecs_autoscaling_min_capacity
  autoscaling_max_capacity       = var.ecs_autoscaling_max_capacity
  autoscaling_cpu_target         = var.ecs_autoscaling_cpu_target
  autoscaling_memory_target      = var.ecs_autoscaling_memory_target
  cpu_architecture               = var.container_cpu_architecture
  task_role_name                 = local.ecs_task_role_name
  execution_role_name            = local.ecs_exec_role_name
  sns_topic_arn                  = aws_sns_topic.alerts.arn
  allowed_alb_ingress_cidrs      = var.allowed_alb_ingress_cidrs
  alb_certificate_arn            = var.alb_certificate_arn
  enable_alb_deletion_protection = var.enable_alb_deletion_protection
  log_retention_days             = var.log_retention_days
  tags                           = local.tags
}

