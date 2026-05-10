# -----------------------------------------------------------------------------
# Platform ECR repositories
#
# Repos for the Astrolift control-plane images (api, ui, worker, status).
# Tenant per-app repos are created at runtime by the AWS provider plugin
# under astrolift/<org>/<app>/<workload>; those are NOT provisioned here.
# -----------------------------------------------------------------------------

locals {
  platform_ecr_repos = ["api", "ui", "worker", "status"]
}

resource "aws_ecr_repository" "platform" {
  for_each = toset(local.platform_ecr_repos)

  name                 = "astrolift/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.tags, {
    Name     = "astrolift-${each.value}"
    Workload = each.value
  })
}

# Expire untagged images after 30 days to control cost.
resource "aws_ecr_lifecycle_policy" "platform" {
  for_each = aws_ecr_repository.platform

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}
