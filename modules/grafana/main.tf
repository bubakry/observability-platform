data "aws_partition" "current" {}

locals {
  role_association_enabled = length(var.admin_user_ids) > 0 || length(var.admin_group_ids) > 0
  grafana_kms_principal    = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:root"
}

data "aws_iam_policy_document" "workspace_kms" {
  statement {
    sid    = "EnableKeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.grafana_kms_principal]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowGrafanaUse"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.grafana_kms_principal]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["grafana.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "AllowGrafanaCreateGrant"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.grafana_kms_principal]
    }

    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["grafana.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:GrantConstraintType"
      values   = ["EncryptionContextSubset"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "kms:GrantOperations"
      values = [
        "CreateGrant",
        "RetireGrant",
        "Decrypt",
        "Encrypt",
        "GenerateDataKey",
        "GenerateDataKeyWithoutPlaintext",
        "ReEncryptFrom",
        "ReEncryptTo",
      ]
    }
  }
}

resource "aws_kms_key" "workspace" {
  description             = "KMS key for Amazon Managed Grafana workspace ${var.name}."
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.workspace_kms.json
  tags                    = var.tags
}

resource "aws_kms_alias" "workspace" {
  name          = "alias/${var.name}/grafana"
  target_key_id = aws_kms_key.workspace.key_id
}

resource "aws_grafana_workspace" "this" {
  name                     = var.name
  description              = var.description
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  data_sources             = ["CLOUDWATCH", "XRAY"]
  grafana_version          = var.grafana_version
  kms_key_id               = aws_kms_key.workspace.arn
  tags                     = var.tags
}

resource "aws_grafana_role_association" "admin" {
  count = local.role_association_enabled ? 1 : 0

  workspace_id = aws_grafana_workspace.this.id
  role         = "ADMIN"
  user_ids     = var.admin_user_ids
  group_ids    = var.admin_group_ids
}

resource "aws_grafana_workspace_api_key" "automation" {
  key_name        = "${var.name}-automation"
  key_role        = "ADMIN"
  seconds_to_live = var.api_key_ttl_seconds
  workspace_id    = aws_grafana_workspace.this.id
}
