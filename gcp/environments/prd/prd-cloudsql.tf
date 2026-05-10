# -----------------------------------------------------------------------------
# Cloud SQL PostgreSQL 16 (regional HA + read replica for production)
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "private_ip" {
  name          = "${local.name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = local.project_id
}

resource "google_service_networking_connection" "private_vpc" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

resource "google_sql_database_instance" "postgres" {
  name             = "${local.name}-db"
  database_version = "POSTGRES_16"
  region           = local.region
  project          = local.project_id

  depends_on = [google_service_networking_connection.private_vpc]

  settings {
    tier              = var.db_tier
    availability_type = var.db_availability_type
    disk_size         = var.db_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = var.db_backup_retention_days
      }
    }

    maintenance_window {
      day          = 1 # Monday
      hour         = 4
      update_track = "stable"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "idle_in_transaction_session_timeout"
      value = "60000"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = local.labels
  }

  # Production: opt out of accidental terraform destroy.
  # Override via -var or remove this line for tear-downs.
  deletion_protection = true
}

resource "google_sql_database" "astrolift" {
  name     = "astrolift"
  instance = google_sql_database_instance.postgres.name
  project  = local.project_id
}

resource "google_sql_user" "astrolift" {
  name     = "astrolift"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = local.project_id
}

resource "random_password" "db_password" {
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# Read replicas — gated on db_read_replica_count (defaults to 1 in prd).
# Replicas inherit tier + disk type from the primary; size auto-resizes.
# Cross-region replicas would need a separate var; same-region by default.
# -----------------------------------------------------------------------------

resource "google_sql_database_instance" "read_replica" {
  count = var.db_read_replica_count

  name                 = "${local.name}-db-replica-${count.index + 1}"
  database_version     = "POSTGRES_16"
  region               = local.region
  project              = local.project_id
  master_instance_name = google_sql_database_instance.postgres.name

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = local.labels
  }

  deletion_protection = true
}
