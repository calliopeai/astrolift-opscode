# -----------------------------------------------------------------------------
# OpenSearch domain (log aggregation)
#
# Gated by enable_opensearch. Deploys a VPC-internal OpenSearch domain in
# the database subnets so Fluent Bit / OTel can ship logs for indexing
# alongside CloudWatch.
# -----------------------------------------------------------------------------

resource "aws_security_group" "opensearch" {
  count = var.enable_opensearch ? 1 : 0

  name_prefix = "${local.name}-opensearch-"
  description = "OpenSearch domain access from VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name}-opensearch"
  })
}

resource "aws_opensearch_domain" "logs" {
  count = var.enable_opensearch ? 1 : 0

  domain_name    = "${local.name}-logs"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 2
    zone_awareness_enabled = true
    zone_awareness_config { availability_zone_count = 2 }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 50
  }

  vpc_options {
    subnet_ids         = slice(module.vpc.database_subnets, 0, 2)
    security_group_ids = [aws_security_group.opensearch[0].id]
  }

  encrypt_at_rest { enabled = true }

  node_to_node_encryption { enabled = true }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-PFS-2023-10"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-logs"
  })
}
