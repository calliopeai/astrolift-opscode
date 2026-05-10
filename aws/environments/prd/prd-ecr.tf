# -----------------------------------------------------------------------------
# Platform ECR repositories
#
# Repos for the Astrolift control-plane images (api, ui, worker, status).
# Tenant per-app repos are created at runtime by the AWS provider plugin
# under astrolift/<org>/<app>/<workload>; those are NOT provisioned here.
#
# image_tag_mutability = IMMUTABLE in production so deploys cannot clobber
# a previously-shipped tag. Roll forward by pushing a new tag.
# -----------------------------------------------------------------------------

locals {
  platform_ecr_repos = ["api", "ui", "worker", "status"]
}

resource "aws_ecr_repository" "platform" {
  for_each = toset(local.platform_ecr_repos)

  name                 = "astrolift/${each.value}"
  image_tag_mutability = "IMMUTABLE"

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

# Expire untagged images after 30 days; in prd we also cap tagged image count
# to keep the registry from growing unbounded across long-running envs.
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
      },
      {
        rulePriority = 2
        description  = "Keep last 100 tagged images per repo"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 100
        }
        action = { type = "expire" }
      }
    ]
  })
}
