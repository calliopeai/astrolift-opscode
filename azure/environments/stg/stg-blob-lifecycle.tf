# -----------------------------------------------------------------------------
# Storage Account blob lifecycle policy (Cool / Archive transitions).
#
# Gated by enable_blob_lifecycle. Transitions noncurrent blob versions
# to Cool after 30 days and Archive after 180 days, then deletes after
# 730 days. Current versions are untouched.
# -----------------------------------------------------------------------------

resource "azurerm_storage_management_policy" "files_lifecycle" {
  count = var.enable_blob_lifecycle ? 1 : 0

  storage_account_id = azurerm_storage_account.files.id

  rule {
    name    = "noncurrent-tiered-archive"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        change_tier_to_cool_after_days_since_creation    = 30
        change_tier_to_archive_after_days_since_creation = 180
        delete_after_days_since_creation                 = 730
      }
    }
  }
}
