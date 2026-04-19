data "aws_partition" "current" {}

locals {
  domain_kms_policy = data.aws_iam_policy_document.domain_kms.json
}

data "aws_iam_policy_document" "domain_kms" {
  statement {
    sid    = "EnableKeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowOpenSearchServiceUse"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:root"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
      "kms:CreateGrant",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["es.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_kms_key" "domain" {
  description             = "KMS key for OpenSearch domain ${var.domain_name}."
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = local.domain_kms_policy
  tags                    = var.tags
}

resource "aws_kms_alias" "domain" {
  name          = "alias/${var.domain_name}/opensearch"
  target_key_id = aws_kms_key.domain.key_id
}

resource "aws_iam_service_linked_role" "opensearch" {
  count = var.create_service_linked_role ? 1 : 0

  aws_service_name = "es.amazonaws.com"
  description      = "Service-linked role required by Amazon OpenSearch Service."
}

resource "aws_security_group" "this" {
  name        = "${var.domain_name}-sg"
  description = "Restricts OpenSearch HTTPS access to the private application subnets."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from the private application subnets."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "Allow OpenSearch to communicate with AWS managed services."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_count   = var.dedicated_master_enabled ? var.dedicated_master_count : null
    dedicated_master_type    = var.dedicated_master_enabled ? var.dedicated_master_type : null
    zone_awareness_enabled   = var.instance_count > 1 && length(var.subnet_ids) > 1

    dynamic "zone_awareness_config" {
      for_each = var.instance_count > 1 && length(var.subnet_ids) > 1 ? [1] : []

      content {
        availability_zone_count = min(var.availability_zone_count, length(var.subnet_ids))
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.domain.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  snapshot_options {
    automated_snapshot_start_hour = 3
  }

  vpc_options {
    subnet_ids         = slice(var.subnet_ids, 0, var.instance_count > 1 ? min(var.availability_zone_count, length(var.subnet_ids)) : 1)
    security_group_ids = [aws_security_group.this.id]
  }

  depends_on = [aws_iam_service_linked_role.opensearch]

  tags = var.tags
}
