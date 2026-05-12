# -----------------------------------------------------------------------------
# Storage Account + Blob Container (S3 equivalent)
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "files" {
  name                     = replace("${local.name}files", "-", "")
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }

  sas_policy {
    expiration_period = "01.00:00:00" # 1 day
    expiration_action = "Log"
  }

  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  blob_properties {
    versioning_enabled = true

    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "PUT", "POST"]
      allowed_origins    = ["https://${local.domain}", "https://*.${local.domain}"]
      exposed_headers    = ["ETag"]
      max_age_in_seconds = 3600
    }

    delete_retention_policy {
      days = 7
    }
  }

  tags = merge(local.tags, {
    Name    = "${local.name}-files"
    Purpose = "Application file storage"
  })
}

# Diagnostic logging for blob read requests (CKV2_AZURE_21).
resource "azurerm_monitor_diagnostic_setting" "files_blob_logs" {
  name                       = "${local.name}-files-blob-logs"
  target_resource_id         = "${azurerm_storage_account.files.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

resource "azurerm_storage_container" "files" {
  name                  = "files"
  storage_account_name  = azurerm_storage_account.files.name
  container_access_type = "private"
}
