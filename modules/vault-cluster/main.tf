# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.12.0 AND ABOVE
# This module has been updated with 0.12 syntax, which means the example is no longer
# compatible with any versions below 0.12.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATES A SERVICE ACCOUNT TO OPERATE THE VAULT CLUSTER
# The default project service account will be used if create_service_account
# is set to false and no service_account_email is provided.
# ---------------------------------------------------------------------------------------------------------------------

resource "google_service_account" "vault_cluster_admin" {
  count        = var.create_service_account ? 1 : 0
  account_id   = "${var.cluster_name}-admin-sa"
  display_name = "Vault Server Admin"
  project      = var.gcp_project_id
}

# Create a service account key
resource "google_service_account_key" "vault" {
  count              = var.create_service_account ? 1 : 0
  service_account_id = google_service_account.vault_cluster_admin[0].name
}

# Add viewer role to service account on project
resource "google_project_iam_member" "vault_cluster_admin_sa_view_project" {
  count   = var.create_service_account ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${local.service_account_email}"
}

# Does the same in case we're using a service account that has been previously created
resource "google_project_iam_member" "other_sa_view_project" {
  count   = var.use_external_service_account ? 1 : 0
  project = var.gcp_project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${var.service_account_email}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A GCE MANAGED INSTANCE GROUP TO RUN VAULT
# Ideally, we would run a "regional" Managed Instance Group that spans many Zones, but the Terraform GCP provider has
# not yet implemented https://github.com/terraform-providers/terraform-provider-google/issues/45, so we settle for a
# single-zone Managed Instance Group.
# ---------------------------------------------------------------------------------------------------------------------

# Create the single-zone Managed Instance Group where Vault will run.
resource "google_compute_region_instance_group_manager" "vault" {
  name = "${var.cluster_name}-ig"

  project = var.gcp_project_id

  base_instance_name = var.cluster_name
  instance_template  = data.template_file.compute_instance_template_self_link.rendered
  region             = var.gcp_region

  # Restarting a Vault server has an important consequence: The Vault server has to be manually unsealed again. Therefore,
  # the update strategy used to roll out a new GCE Instance Template must be a rolling update. But since Terraform does
  # not yet support ROLLING_UPDATE, such updates must be manually rolled out for now.
  update_strategy = var.instance_group_update_strategy

  target_pools = var.instance_group_target_pools
  target_size  = var.cluster_size

  depends_on = [
    google_compute_instance_template.vault_public,
    google_compute_instance_template.vault_private,
  ]
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is true.
resource "google_compute_instance_template" "vault_public" {
  count = var.assign_public_ip_addresses ? 1 : 0

  name_prefix = var.cluster_name
  description = var.cluster_description
  project     = var.gcp_project_id

  instance_description = var.cluster_description
  machine_type         = var.machine_type

  tags                    = concat([var.cluster_tag_name], var.custom_tags)
  metadata_startup_script = var.startup_script
  metadata = merge(
    {
      "${var.metadata_key_name_for_cluster_size}" = var.cluster_size
    },
    var.custom_metadata,
  )

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = data.google_compute_image.image.self_link
    disk_size_gb = var.root_volume_disk_size_gb
    disk_type    = var.root_volume_disk_type
  }

  network_interface {
    # Either network or subnetwork must both be blank, or exactly one must be provided.
    network            = var.subnetwork_name != null ? null : var.network_name
    subnetwork         = var.subnetwork_name != null ? var.subnetwork_name : null
    subnetwork_project = var.network_project_id != null ? var.network_project_id : var.gcp_project_id

    access_config {
      # The presence of this property assigns a public IP address to each Compute Instance. We intentionally leave it
      # blank so that an external IP address is selected automatically.
      nat_ip = null
    }
  }

  # For a full list of oAuth 2.0 Scopes, see https://developers.google.com/identity/protocols/googlescopes
  service_account {
    email = local.service_account_email
    scopes = concat(
      [
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.read_write",
        "https://www.googleapis.com/auth/cloud-platform",
      ],
      var.service_account_scopes,
    )
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }
}

# Create the Instance Template that will be used to populate the Managed Instance Group.
# NOTE: This Compute Instance Template is only created if var.assign_public_ip_addresses is false.
resource "google_compute_instance_template" "vault_private" {
  count = var.assign_public_ip_addresses ? 0 : 1

  name_prefix = var.cluster_name
  description = var.cluster_description
  project     = var.gcp_project_id

  instance_description    = var.cluster_description
  machine_type            = var.machine_type
  tags                    = concat([var.cluster_tag_name], var.custom_tags)
  metadata_startup_script = var.startup_script
  metadata = merge(
    {
      "${var.metadata_key_name_for_cluster_size}" = var.cluster_size
    },
    var.custom_metadata,
  )

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  disk {
    boot         = true
    auto_delete  = true
    source_image = data.google_compute_image.image.self_link
    disk_size_gb = var.root_volume_disk_size_gb
    disk_type    = var.root_volume_disk_type
  }

  network_interface {
    network            = var.subnetwork_name != null ? null : var.network_name
    subnetwork         = var.subnetwork_name != null ? var.subnetwork_name : null
    subnetwork_project = var.network_project_id != null ? var.network_project_id : var.gcp_project_id
  }

  # For a full list of oAuth 2.0 Scopes, see https://developers.google.com/identity/protocols/googlescopes
  service_account {
    email = local.service_account_email
    scopes = concat(
      [
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.read_write",
        "https://www.googleapis.com/auth/cloud-platform",
      ],
      var.service_account_scopes,
    )
  }

  # Per Terraform Docs (https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#using-with-instance-group-manager),
  # we need to create a new instance template before we can destroy the old one. Note that any Terraform resource on
  # which this Terraform resource depends will also need this lifecycle statement.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE FIREWALL RULES
# ---------------------------------------------------------------------------------------------------------------------

# Allow Vault-specific traffic within the cluster
# - This Firewall Rule may be redundant depending on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
resource "google_compute_firewall" "allow_intracluster_vault" {
  name    = "${var.cluster_name}-rule-cluster"
  network = var.network_name
  project = var.network_project_id != null ? var.network_project_id : var.gcp_project_id

  allow {
    protocol = "tcp"

    ports = [
      var.cluster_port,
    ]
  }

  source_tags = [var.cluster_tag_name]
  target_tags = [var.cluster_tag_name]
}

# Specify which traffic is allowed into the Vault cluster solely for API requests
# - This Firewall Rule may be redundant depending on the settings of your VPC Network, but if your Network is locked down,
#   this Rule will open up the appropriate ports.
# - Note that public access to your Vault cluster will only be permitted if var.assign_public_ip_addresses is true.
# - This Firewall Rule is only created if at least one source tag or source CIDR block is specified.
resource "google_compute_firewall" "allow_inbound_api" {
  count = length(var.allowed_inbound_cidr_blocks_api) + length(var.allowed_inbound_tags_api) > 0 ? 1 : 0

  name    = "${var.cluster_name}-rule-external-api-access"
  network = var.network_name
  project = var.network_project_id != null ? var.network_project_id : var.gcp_project_id

  allow {
    protocol = "tcp"

    ports = [
      var.api_port,
    ]
  }

  source_ranges = var.allowed_inbound_cidr_blocks_api
  source_tags   = var.allowed_inbound_tags_api
  target_tags   = [var.cluster_tag_name]
}

# If we require a Load Balancer in front of the Vault cluster, we must specify a Health Check so that the Load Balancer
# knows which nodes to route to. But GCP only permits HTTP Health Checks, not HTTPS Health Checks (https://github.com/terraform-providers/terraform-provider-google/issues/18)
# so we must run a separate Web Proxy that forwards HTTP requests to the HTTPS Vault health check endpoint. This Firewall
# Rule permits only the Google Cloud Health Checker to make such requests.
resource "google_compute_firewall" "allow_inbound_health_check" {
  count = var.enable_web_proxy ? 1 : 0

  name    = "${var.cluster_name}-rule-health-check"
  network = var.network_name

  project = var.network_project_id != null ? var.network_project_id : var.gcp_project_id

  allow {
    protocol = "tcp"

    ports = [
      var.web_proxy_port,
    ]
  }

  # Per https://goo.gl/xULu8U, all Google Cloud Health Check requests will be sent from 35.191.0.0/16
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = [var.cluster_tag_name]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A GOOGLE STORAGE BUCKET TO USE AS A VAULT STORAGE BACKEND
# ---------------------------------------------------------------------------------------------------------------------

resource "google_storage_bucket" "vault_storage_backend" {
  name          = var.gcs_bucket_name != "" ? var.gcs_bucket_name : var.cluster_name
  location      = var.gcs_bucket_location
  storage_class = var.gcs_bucket_storage_class
  project       = var.gcp_project_id

  # In prod, the Storage Bucket should NEVER be emptied and deleted via Terraform unless you know exactly what you're doing.
  # However, for testing purposes, it's often convenient to destroy a non-empty Storage Bucket.
  force_destroy = var.gcs_bucket_force_destroy
}

# ACLs are now deprecated as a way to secure a GCS Bucket (https://goo.gl/PgDCYb0), however the Terraform Google Provider
# does not yet expose a way to attach an IAM Policy to a Google Bucket so we resort to using the Bucket ACL in case users
# of this module wish to limit Bucket permissions via Terraform.
resource "google_storage_bucket_acl" "vault_storage_backend" {
  bucket         = google_storage_bucket.vault_storage_backend.name
  predefined_acl = var.gcs_bucket_predefined_acl
}

# Allows a provided service account to create and read objects from the storage
resource "google_storage_bucket_iam_binding" "external_service_acc_binding" {
  count  = var.use_external_service_account ? 1 : 0
  bucket = google_storage_bucket.vault_storage_backend.name
  role   = "roles/storage.objectAdmin"

  members = [
    "serviceAccount:${var.service_account_email}",
  ]

  depends_on = [
    google_storage_bucket.vault_storage_backend,
    google_storage_bucket_acl.vault_storage_backend,
  ]
}

# Allows a provided service account to create and read objects from the storage
resource "google_storage_bucket_iam_binding" "vault_cluster_admin_service_acc_binding" {
  count  = var.create_service_account ? 1 : 0
  bucket = google_storage_bucket.vault_storage_backend.name
  role   = "roles/storage.objectAdmin"

  members = [
    "serviceAccount:${google_service_account.vault_cluster_admin[0].email}",
  ]

  depends_on = [
    google_storage_bucket.vault_storage_backend,
    google_storage_bucket_acl.vault_storage_backend,
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONVENIENCE VARIABLES
# Because we've got some conditional logic in this template, some values will depend on our properties. This section
# wraps such values in a nicer construct.
# ---------------------------------------------------------------------------------------------------------------------

# The Google Compute Instance Group needs the self_link of the Compute Instance Template that's actually created.
data "template_file" "compute_instance_template_self_link" {
  # This will return the self_link of the Compute Instance Template that is actually created. It works as follows:
  # - Make a list of 1 value or 0 values for each of google_compute_instance_template.consul_servers_public and
  #   google_compute_instance_template.consul_servers_private by adding the glob (*) notation. Terraform will complain
  #   if we directly reference a resource property that doesn't exist, but it will permit us to turn a single resource
  #   into a list of 1 resource and "no resource" into an empty list.
  # - Concat these lists. concat(list-of-1-value, empty-list) == list-of-1-value
  # - Take the first element of list-of-1-value
  template = element(
    concat(
      google_compute_instance_template.vault_public.*.self_link,
      google_compute_instance_template.vault_private.*.self_link,
    ),
    0,
  )
}

# This is a workaround for a provider bug in Terraform v0.11.8. For more information please refer to:
# https://github.com/terraform-providers/terraform-provider-google/issues/2067.
data "google_compute_image" "image" {
  name    = var.source_image
  project = var.image_project_id != null ? var.image_project_id : var.gcp_project_id
}

# This is a work around so we don't have yet another combination of google_compute_instance_template
# with counts that depend on yet another flag
locals {
  service_account_email = var.create_service_account ? element(
    concat(google_service_account.vault_cluster_admin.*.email, [""]),
    0,
  ) : var.service_account_email
}
