variable "region" {
  description = "AWS region for this environment (no default; set via aws/config.env or -var)"
  type        = string
}

variable "base_domain" {
  description = "Base DNS zone for this environment (e.g. acme.com or platform.acme.com). Operator must own this zone or have NS delegation to Route53."
  type        = string
}

# -----------------------------------------------------------------------------
# Production Environment Variables
# Override defaults via terraform.tfvars or -var flags.
# -----------------------------------------------------------------------------

# Container runtime selection — enable one or both
variable "enable_ecs" {
  description = "Enable ECS Fargate container runtime"
  type        = bool
  default     = true
}

variable "enable_eks" {
  description = "Enable EKS Kubernetes container runtime"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Observability + backup toggles
#
# Optional components. Defaults follow a dev=light / stg=most / prd=full ladder.
# Self-hosted operators flip these to opt out of managed services they lack
# access to (e.g. AMP/AMG aren't available on every account).
# -----------------------------------------------------------------------------

variable "enable_fluent_bit" {
  description = "Deploy Fluent Bit DaemonSet shipping pod logs to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "enable_amp_amg" {
  description = "Provision Amazon Managed Prometheus + Amazon Managed Grafana"
  type        = bool
  default     = true
}

variable "enable_otel_xray" {
  description = "Deploy OpenTelemetry collector with X-Ray exporter for traces"
  type        = bool
  default     = true
}

variable "enable_opensearch" {
  description = "Provision OpenSearch cluster for log aggregation"
  type        = bool
  default     = true
}

variable "enable_velero" {
  description = "Install Velero for cluster-wide PV snapshots to S3"
  type        = bool
  default     = true
}

variable "enable_aws_backup" {
  description = "Wire RDS, EFS, DynamoDB into AWS Backup vault + plan"
  type        = bool
  default     = true
}

variable "enable_s3_glacier_lifecycle" {
  description = "Apply Glacier transition lifecycle to S3 bucket noncurrent versions"
  type        = bool
  default     = true
}

variable "enable_email_events" {
  description = "Provision SNS topic + HTTPS webhook subscription for SES email events (SEND/DELIVERY/BOUNCE/COMPLAINT/OPEN/CLICK)"
  type        = bool
  default     = true
}

# ECS settings
variable "container_image" {
  description = "Docker image for the ECS task (ECR URI)"
  type        = string
  default     = "nginx:latest"
}

variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "ECS task memory (MiB)"
  type        = number
  default     = 2048
}

# Database
variable "db_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "db_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 16
}

# Cache
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.r7g.large"
}

# Bastion
variable "allowed_bastion_ips" {
  description = "CIDR blocks allowed to SSH into the bastion host"
  type        = list(string)
  default     = []
}

variable "bastion_key_name" {
  description = "EC2 key pair name for the bastion host"
  type        = string
  default     = ""
}
