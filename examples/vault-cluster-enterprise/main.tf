# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A VAULT CLUSTER IN GOOGLE CLOUD
# This is an example of how to use the vault-cluster to deploy a private Vault cluster in GCP with a Load Balancer in
# front of it. This cluster uses Consul, running in a separate cluster, as its High Availability backend.
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  project = "${var.gcp_project_id}"
  region  = "${var.gcp_region}"
}

# Use Terraform 0.10.x so that we can take advantage of Terraform GCP functionality as a separate provider via
# https://github.com/terraform-providers/terraform-provider-google
terraform {
  required_version = ">= 0.10.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATES A SUBNETWORK WITH GOOGLE API ACCESS
# Necessary because the private cluster doesn't have internet access
# But consul needs to make requests to the Google API
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_subnetwork" "private_subnet_with_google_api_access" {
  name                     = "${var.vault_cluster_name}-private-subnet-with-google-api-access"
  private_ip_google_access = true
  network                  = "${var.network_name}"
  ip_cidr_range            = "10.2.0.0/16"
}

# ---------------------------------------------------------------------------------------------------------------------
# ALLOW SERVICE ACCOUNT TO USE THE CRYPTOGRAPHIC KEY FROM CLOUD KMS
# ---------------------------------------------------------------------------------------------------------------------

data "google_service_account" "vault_test" {
  account_id = "${var.service_account_name}"
}

resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  crypto_key_id = "${var.vault_auto_unseal_key_project_id}/${var.vault_auto_unseal_key_region}/${var.vault_auto_unseal_key_ring}/${var.vault_auto_unseal_crypto_key_name}"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${data.google_service_account.vault_test.email}",
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOYS A BASTION HOST THAT CAN REACH THE CLUSTER
# We can't ssh directly to the clusters because they don't have an external IP
# address, but we can ssh to a bastion host inside the same subnet and then
# access the cluster
# ---------------------------------------------------------------------------------------------------------------------

data "google_compute_zones" "available" {}

resource "google_compute_instance" "bastion" {
  name         = "${var.bastion_server_name}"
  zone         = "${data.google_compute_zones.available.names[0]}"
  machine_type = "g1-small"

  boot_disk {
    initialize_params {
      image = "ubuntu-1810-cosmic-v20181114"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.private_subnet_with_google_api_access.self_link}"

    access_config {
      // Ephemeral IP - leaving this block empty will generate a new external IP and assign it to the machine
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE VAULT SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "vault_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-google-vault.git//modules/vault-cluster?ref=v0.0.1"
  source = "../../modules/vault-cluster"

  subnetwork_name = "${google_compute_subnetwork.private_subnet_with_google_api_access.name}"

  gcp_project_id = "${var.gcp_project_id}"
  gcp_region     = "${var.gcp_region}"

  cluster_name     = "${var.vault_cluster_name}"
  cluster_size     = "${var.vault_cluster_size}"
  cluster_tag_name = "${var.vault_cluster_name}"
  machine_type     = "${var.vault_cluster_machine_type}"

  source_image   = "${var.vault_source_image}"
  startup_script = "${data.template_file.startup_script_vault.rendered}"

  gcs_bucket_name          = "${var.vault_cluster_name}"
  gcs_bucket_location      = "${var.gcs_bucket_location}"
  gcs_bucket_storage_class = "${var.gcs_bucket_class}"
  gcs_bucket_force_destroy = "${var.gcs_bucket_force_destroy}"

  root_volume_disk_size_gb = "${var.root_volume_disk_size_gb}"
  root_volume_disk_type    = "${var.root_volume_disk_type}"

  # Regrettably, GCE only supports HTTP health checks, not HTTPS Health Checks (https://github.com/terraform-providers/terraform-provider-google/issues/18)
  # But Vault is only configured to listen for HTTPS requests. Therefore, per GCE recommendations, we run a simple HTTP
  # proxy server that forwards all requests to the Vault Health Check URL specified in the startup-script-vault.sh
  enable_web_proxy = true

  web_proxy_port = "${var.web_proxy_port}"

  # Even when the Vault cluster is pubicly accessible via a Load Balancer, we still make the Vault nodes themselves
  # private to improve the overall security posture. Note that the only way to reach private nodes via SSH is to first
  # SSH into another node that is not private.
  assign_public_ip_addresses = false

  # To enable external access to the Vault Cluster, enter the approved CIDR Blocks below.
  # Allowing from all for test purposes, do NOT use this value for production
  allowed_inbound_cidr_blocks_api = ["0.0.0.0/0"]

  # To access to the Vault Cluster from other resources inside Google Cloud,
  # add their tags below, along with the Consul Server, which needs to send
  # health checks to the Vault cluster.
  allowed_inbound_tags_api = ["${concat(list(var.consul_server_cluster_name), var.additional_allowed_inbound_tags_api)}"]

  # This property is only necessary when using a Load Balancer
  instance_group_target_pools = ["${module.vault_load_balancer.target_pool_url}"]

  # Ensure the cluster can access the Cloud KMS resources
  service_account_email  = "${data.google_service_account.vault_test.email}"
  service_account_scopes = ["cloud-platform"]
}

# Render the Startup Script that will run on each Vault Instance on boot. This script will configure and start Vault.
data "template_file" "startup_script_vault" {
  template = "${file("${path.module}/startup-script-vault-enterprise.sh")}"

  vars {
    consul_cluster_tag_name = "${var.consul_server_cluster_name}"
    vault_cluster_tag_name  = "${var.vault_cluster_name}"
    web_proxy_port          = "${var.web_proxy_port}"

    # Enable the Vault Enterprise Auto Unseal feature.
    vault_auto_unseal_key_project_id  = "${var.vault_auto_unseal_key_project_id}"
    vault_auto_unseal_key_region      = "${var.vault_auto_unseal_key_region}"
    vault_auto_unseal_key_ring        = "${var.vault_auto_unseal_key_ring}"
    vault_auto_unseal_crypto_key_name = "${var.vault_auto_unseal_crypto_key_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------

module "vault_load_balancer" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-google-vault.git//modules/vault-lb-regional-ext?ref=v0.0.1"
  source = "../../modules/vault-lb-fr"

  cluster_name     = "${var.vault_cluster_name}"
  cluster_tag_name = "${var.vault_cluster_name}"

  health_check_path = "/"
  health_check_port = "${var.web_proxy_port}"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "consul_cluster" {
  source = "git::git@github.com:hashicorp/terraform-google-consul.git//modules/consul-cluster?ref=v0.2.1"

  subnetwork_name = "${google_compute_subnetwork.private_subnet_with_google_api_access.name}"

  gcp_region = "${var.gcp_region}"

  cluster_name     = "${var.consul_server_cluster_name}"
  cluster_tag_name = "${var.consul_server_cluster_name}"
  cluster_size     = "${var.consul_server_cluster_size}"

  source_image = "${var.consul_server_source_image}"
  machine_type = "${var.consul_server_machine_type}"

  startup_script = "${data.template_file.startup_script_consul.rendered}"

  # In a production setting, we strongly recommend only launching a Consul Server cluster as private nodes.
  # Note that the only way to reach private nodes via SSH is to first SSH into another node that is not private.
  assign_public_ip_addresses = false

  allowed_inbound_tags_dns      = ["${var.vault_cluster_name}"]
  allowed_inbound_tags_http_api = ["${var.vault_cluster_name}"]
}

# This Startup Script will run at boot configure and start Consul on the Consul Server cluster nodes
data "template_file" "startup_script_consul" {
  template = "${file("${path.module}/startup-script-consul.sh")}"

  vars {
    cluster_tag_name = "${var.consul_server_cluster_name}"
  }
}
