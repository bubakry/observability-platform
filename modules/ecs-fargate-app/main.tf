data "aws_partition" "current" {}

locals {
  cluster_name            = "${var.name}-cluster"
  service_name            = "${var.name}-service"
  task_family             = "${var.name}-task"
  application_log_group   = "/aws/${var.name}/application"
  firelens_log_group      = "/aws/${var.name}/firelens"
  xray_log_group          = "/aws/${var.name}/xray"
  app_signing_secret_name = "${var.name}/app-signing-key"
  application_name        = "enterprise-observability-api"
  https_enabled           = var.alb_certificate_arn != null && trimspace(var.alb_certificate_arn) != ""

  # ALB and target group names are capped at 32 characters. The Grafana module
  # uses the same prefix and would collide after truncation, so the app side
  # uses an explicit "-app-" infix.
  safe_name_prefix  = replace(var.name, "_", "-")
  alb_name          = "${substr(local.safe_name_prefix, 0, 24)}-app-alb"
  target_group_name = "${substr(local.safe_name_prefix, 0, 25)}-app-tg"
}

resource "aws_cloudwatch_log_group" "application" {
  name              = local.application_log_group
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "firelens" {
  name              = local.firelens_log_group
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "xray" {
  name              = local.xray_log_group
  retention_in_days = var.log_retention_days
}

resource "random_password" "app_signing_key" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "app_signing_key" {
  name        = local.app_signing_secret_name
  description = "Sample application runtime secret injected into ECS as an environment variable."
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "app_signing_key" {
  secret_id     = aws_secretsmanager_secret.app_signing_key.id
  secret_string = random_password.app_signing_key.result
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allows configured CIDRs to reach the internet-facing ALB on HTTP."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP ingress from configured CIDR blocks."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_alb_ingress_cidrs
  }

  dynamic "ingress" {
    for_each = local.https_enabled ? [1] : []

    content {
      description = "HTTPS ingress from configured CIDR blocks."
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_alb_ingress_cidrs
    }
  }

  egress {
    description = "Allow the ALB to reach the ECS tasks."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "service" {
  name        = "${var.name}-service-sg"
  description = "Restricts ECS ingress to the ALB while allowing outbound HTTPS to AWS services."
  vpc_id      = var.vpc_id

  ingress {
    description     = "ALB to FastAPI application."
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound traffic to VPC endpoints, OpenSearch, and AWS managed control planes."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_lb" "this" {
  name                       = local.alb_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  idle_timeout               = 60
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_alb_deletion_protection

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  name        = local.target_group_name
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []

    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https_enabled ? [] : [1]

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

data "aws_iam_policy_document" "task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "task" {
  name               = var.task_role_name
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role" "execution" {
  name               = var.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_inline" {
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [aws_secretsmanager_secret.app_signing_key.arn]
  }
}

resource "aws_iam_role_policy" "execution_inline" {
  name   = "${var.name}-execution-inline"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_inline.json
}

data "aws_iam_policy_document" "task_inline" {
  statement {
    sid    = "AllowXRayWrites"
    effect = "Allow"
    actions = [
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowFireLensCloudWatchWrites"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      aws_cloudwatch_log_group.application.arn,
      "${aws_cloudwatch_log_group.application.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "task_inline" {
  name   = "${var.name}-task-inline"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_inline.json
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.app_cpu)
  memory                   = tostring(var.app_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name              = "log_router"
      image             = var.firelens_image_uri
      essential         = true
      cpu               = 64
      memoryReservation = 128
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
          "config-file-type"        = "file"
          "config-file-value"       = "/fluent-bit/custom.conf"
        }
      }
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "APPLICATION_LOG_GROUP"
          value = aws_cloudwatch_log_group.application.name
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = "false"
          "awslogs-group"         = aws_cloudwatch_log_group.firelens.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "firelens"
        }
      }
    },
    {
      name              = "xray"
      image             = var.xray_image_uri
      essential         = true
      cpu               = 32
      memoryReservation = 64
      portMappings = [
        {
          containerPort = 2000
          hostPort      = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = "false"
          "awslogs-group"         = aws_cloudwatch_log_group.xray.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    },
    {
      name              = "app"
      image             = var.app_image_uri
      essential         = true
      cpu               = 160
      memoryReservation = 320
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "log_router"
          condition     = "START"
        },
        {
          containerName = "xray"
          condition     = "START"
        }
      ]
      environment = [
        {
          name  = "APP_NAME"
          value = local.application_name
        },
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        },
        {
          name  = "XRAY_DAEMON_ADDRESS"
          value = "127.0.0.1:2000"
        },
      ]
      secrets = [
        {
          name      = "APP_SIGNING_KEY"
          valueFrom = aws_secretsmanager_secret.app_signing_key.arn
        },
      ]
      logConfiguration = {
        logDriver = "awsfirelens"
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name             = local.service_name
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = var.desired_count
  platform_version = "LATEST"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_ecs_cluster_capacity_providers.this,
  ]

  tags = var.tags
}

resource "aws_appautoscaling_target" "service" {
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.autoscaling_cpu_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = aws_appautoscaling_target.service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.autoscaling_memory_target
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${var.name}-application-errors"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "ApplicationErrorCount"
    namespace = "${var.name}/application"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.name}-ecs-cpu-high"
  alarm_description   = "Proactively alerts when ECS CPU remains elevated."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name          = "${var.name}-alb-target-5xx"
  alarm_description   = "Detects application-side HTTP 5xx responses behind the ALB."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.name}-application-errors"
  alarm_description   = "Surfaces structured error logs emitted by the FastAPI service."
  namespace           = "${var.name}/application"
  metric_name         = "ApplicationErrorCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "healthy_targets" {
  alarm_name          = "${var.name}-healthy-targets"
  alarm_description   = "Protects the 99.99% availability target by alerting when healthy targets drop below one."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.this.arn_suffix
  }
}

output "application_url" {
  description = "Application URL, using HTTPS when an ACM certificate is configured."
  value       = local.https_enabled ? "https://${aws_lb.this.dns_name}" : "http://${aws_lb.this.dns_name}"
}

output "alb_https_enabled" {
  description = "Indicates whether the load balancer exposes HTTPS."
  value       = local.https_enabled
}
