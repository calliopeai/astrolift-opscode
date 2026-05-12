# -----------------------------------------------------------------------------
# Memorystore Redis 7 (Standard HA, multi-zone replicated for staging)
# -----------------------------------------------------------------------------

resource "google_redis_instance" "redis" {
  name           = "${local.name}-redis"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  region         = local.region
  project        = local.project_id

  redis_version = "REDIS_7_0"

  # STANDARD_HA replicates across zones automatically; the provider rejects
  # replica_count for BASIC, so only set it on Standard.
  replica_count = var.redis_tier == "STANDARD_HA" ? 1 : null

  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # In-transit TLS + AUTH (CKV_GCP_95, CKV_GCP_97).
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  auth_enabled            = true

  redis_configs = {
    maxmemory-policy = "volatile-lru"
  }

  maintenance_policy {
    weekly_maintenance_window {
      day = "MONDAY"
      start_time {
        hours   = 6
        minutes = 0
      }
    }
  }

  labels = local.labels

  depends_on = [google_service_networking_connection.private_vpc]
}
