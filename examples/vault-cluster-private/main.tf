# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A VAULT CLUSTER IN GOOGLE CLOUD
# This is an example of how to use the vault-cluster and vault-load-balancer modules to deploya Vault cluster in GCP with
# a Load Balancer in front of it. This cluster uses Consul, running in a separate cluster, as its High Availability backend.
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

terraform {
  required_version = ">= 0.10.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE VAULT SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "vault_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/vault-aws-blueprint.git//modules/vault-cluster?ref=v0.0.1"
  source = "../../modules/vault-cluster"

  gcp_zone = "${var.gcp_zone}"

  cluster_name = "${var.vault_cluster_name}"
  cluster_size = "${var.vault_cluster_size}"
  cluster_tag_name = "${var.vault_cluster_name}"
  machine_type = "${var.vault_cluster_machine_type}"

  source_image = "${var.vault_source_image}"
  startup_script = "${data.template_file.startup_script_vault.rendered}"

  gcs_bucket_name = "${var.vault_cluster_name}"
  gcs_bucket_location = "${var.gcs_bucket_location}"
  gcs_bucket_storage_class = "${var.gcs_bucket_class}"
  gcs_bucket_force_destroy = "${var.gcs_bucket_force_destroy}"

  assign_public_ip_addresses = false

  # To enable external access to the Vault Cluster, enter the approved CIDR Blocks or tags below.
  allowed_inbound_cidr_blocks_api = []
  allowed_inbound_tags_api = []
}

# Render the Startup Script that will run on each Vault Instance on boot.
# This script will configure and start Vault.
data "template_file" "startup_script_vault" {
  template = "${file("${path.module}/startup-script-vault.sh")}"

  vars {
    consul_cluster_tag_name = "${var.consul_server_cluster_name}"
    vault_cluster_tag_name = "${var.vault_cluster_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "consul_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-google-consul.git//modules/consul-cluster?ref=v0.0.2"

  gcp_zone = "${var.gcp_zone}"
  cluster_name = "${var.consul_server_cluster_name}"
  cluster_tag_name = "${var.consul_server_cluster_name}"
  cluster_size = "${var.consul_server_cluster_size}"

  source_image = "${var.consul_server_source_image}"
  machine_type = "${var.consul_server_machine_type}"

  startup_script = "${data.template_file.startup_script_consul.rendered}"

  assign_public_ip_addresses = true

  allowed_inbound_tags_dns = ["${var.vault_cluster_name}"]
  allowed_inbound_tags_http_api = ["${var.vault_cluster_name}"]
}

# This Startup Script will run at boot configure and start Consul on the Consul Server cluster nodes
data "template_file" "startup_script_consul" {
  template = "${file("${path.module}/startup-script-consul.sh")}"

  vars {
    cluster_tag_name   = "${var.consul_server_cluster_name}"
  }
}