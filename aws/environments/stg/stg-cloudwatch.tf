# -----------------------------------------------------------------------------
# CloudWatch — Shared (SNS topic for alerts)
#
# Compute-specific log groups and alarms live in ecs/ and eks/ submodules.
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(local.tags, {
    Name = "${local.name}-alerts"
  })
}
