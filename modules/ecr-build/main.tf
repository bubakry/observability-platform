locals {
  app_context_hash      = sha256(join("", [for file in sort(fileset(var.app_source_path, "**")) : filesha256("${var.app_source_path}/${file}")]))
  firelens_context_hash = sha256(join("", [for file in sort(fileset(var.firelens_source_path, "**")) : filesha256("${var.firelens_source_path}/${file}")]))
  xray_context_hash     = sha256(join("", [for file in sort(fileset(var.xray_source_path, "**")) : filesha256("${var.xray_source_path}/${file}")]))

  # Default to a content-addressable tag so IMMUTABLE repositories accept every push.
  app_image_tag      = coalesce(var.app_image_tag, substr(local.app_context_hash, 0, 16))
  firelens_image_tag = coalesce(var.firelens_image_tag, substr(local.firelens_context_hash, 0, 16))
  xray_image_tag     = coalesce(var.xray_image_tag, substr(local.xray_context_hash, 0, 16))
}

resource "aws_ecr_repository" "app" {
  name                 = "${var.name}-app"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_repository" "firelens" {
  name                 = "${var.name}-firelens"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_repository" "xray" {
  name                 = "${var.name}-xray-daemon"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain the latest five application images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "firelens" {
  repository = aws_ecr_repository.firelens.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain the latest five FireLens images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "xray" {
  repository = aws_ecr_repository.xray.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain the latest five mirrored X-Ray daemon images."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "terraform_data" "build_images" {
  triggers_replace = [
    aws_ecr_repository.app.repository_url,
    aws_ecr_repository.firelens.repository_url,
    aws_ecr_repository.xray.repository_url,
    var.image_platform,
    local.app_image_tag,
    local.firelens_image_tag,
    local.xray_image_tag,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      docker buildx version >/dev/null

      REGISTRY_HOST="${split("/", aws_ecr_repository.app.repository_url)[0]}"

      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin "$REGISTRY_HOST"

      docker buildx build --platform ${var.image_platform} --tag ${aws_ecr_repository.app.repository_url}:${local.app_image_tag} --push ${var.app_source_path}
      docker buildx build --platform ${var.image_platform} --tag ${aws_ecr_repository.firelens.repository_url}:${local.firelens_image_tag} --push ${var.firelens_source_path}
      docker buildx build --platform ${var.image_platform} --tag ${aws_ecr_repository.xray.repository_url}:${local.xray_image_tag} --push ${var.xray_source_path}
    EOT
  }
}

