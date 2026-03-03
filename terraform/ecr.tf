# ============================================================
# ecr.tf — Elastic Container Registry
# ============================================================
# WHAT THIS FILE DOES:
# Creates private Docker image repositories in AWS.
# Jenkins builds Docker images and pushes them here.
# EKS pulls images from here when deploying pods.
# One repository per microservice.
# ============================================================

locals {
  # List of all microservices — one ECR repo per service
  services = ["frontend", "product-api", "order-api", "payment-service", "notification-service"]
}

resource "aws_ecr_repository" "services" {
  for_each = toset(local.services)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "MUTABLE"   # Allows overwriting tags (needed for latest)

  # Scan images for security vulnerabilities on every push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${each.value}"
  }
}

# ── ECR Lifecycle Policy ─────────────────────────────────────
# Keeps only the last 10 images per repo — prevents storage buildup
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
