# -----------------------------------------------------------------------------
# S3 Glacier lifecycle for the artifacts bucket (gated by toggle).
#
# Transitions noncurrent versions to Glacier Flexible Retrieval after 30
# days, then to Deep Archive after 180 days; expires them after 730 days
# (2 years). Current versions are left untouched.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "artifacts_glacier" {
  count = var.enable_s3_glacier_lifecycle ? 1 : 0

  bucket = aws_s3_bucket.files.id

  rule {
    id     = "noncurrent-tiered-archive"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 180
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 730
    }
  }
}
