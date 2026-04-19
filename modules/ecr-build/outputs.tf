output "app_repository_url" {
  description = "ECR repository URL for the application image."
  value       = aws_ecr_repository.app.repository_url
}

output "firelens_repository_url" {
  description = "ECR repository URL for the FireLens image."
  value       = aws_ecr_repository.firelens.repository_url
}

output "xray_repository_url" {
  description = "ECR repository URL for the X-Ray daemon image."
  value       = aws_ecr_repository.xray.repository_url
}

output "app_image_uri" {
  description = "Fully qualified application image URI."
  value       = "${aws_ecr_repository.app.repository_url}:${local.app_image_tag}"
}

output "firelens_image_uri" {
  description = "Fully qualified FireLens image URI."
  value       = "${aws_ecr_repository.firelens.repository_url}:${local.firelens_image_tag}"
}

output "xray_image_uri" {
  description = "Fully qualified X-Ray daemon image URI."
  value       = "${aws_ecr_repository.xray.repository_url}:${local.xray_image_tag}"
}

