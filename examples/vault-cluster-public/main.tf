# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A VAULT CLUSTER IN GOOGLE CLOUD
# This is an example of how to use the vault-cluster to deploy a private Vault cluster in GCP with a Load Balancer in
# front of it. This cluster uses Consul, running in a separate cluster, as its High Availability backend.
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

# Use Terraform 0.10.x so that we can take advantage of Terraform GCP functionality as a separate provider via
# https://github.com/terraform-providers/terraform-provider-google
terraform {
  required_version = ">= 0.10.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE VAULT SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "vault_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-google-vault.git//modules/vault-cluster?ref=v0.0.1"
  source = "../../modules/vault-cluster"

  gcp_region = "${var.gcp_region}"

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

  root_volume_disk_size_gb = "${var.root_volume_disk_size_gb}"
  root_volume_disk_type = "${var.root_volume_disk_type}"

  # Regrettably, GCE only supports HTTP health checks, not HTTPS Health Checks (https://github.com/terraform-providers/terraform-provider-google/issues/18)
  # But Vault is only configured to listen for HTTPS requests. Therefore, per GCE recommendations, we run a simple HTTP
  # proxy server that forwards all requests to the Vault Health Check URL specified in the startup-script-vault.sh
  enable_web_proxy = true
  web_proxy_port = "${var.web_proxy_port}"

  # Even when the Vault cluster is pubicly accessible via a Load Balancer, we still make the Vault nodes themselves
  # private to improve the overall security posture. Note that the only way to reach private nodes via SSH is to first
  # SSH into another node that is not private.
  assign_public_ip_addresses = false

  # To enable external access to the Vault Cluster, enter the approved CIDR Blocks or tags below.
  # We enable health checks from the Consul Server cluster to Vault.
  allowed_inbound_cidr_blocks_api = []
  allowed_inbound_tags_api = ["${var.consul_server_cluster_name}"]

  # This property is only necessary when using a Load Balancer
  instance_group_target_pools = ["${module.vault_load_balancer.target_pool_url}"]
}

# Render the Startup Script that will run on each Vault Instance on boot. This script will configure and start Vault.
data "template_file" "startup_script_vault" {
  template = "${file("${path.module}/startup-script-vault.sh")}"

  vars {
    consul_cluster_tag_name = "${var.consul_server_cluster_name}"
    vault_cluster_tag_name = "${var.vault_cluster_name}"
    web_proxy_port = "${var.web_proxy_port}"
    enable_vault_ui = "${var.enable_vault_ui ? "--enable-vault-ui" : ""}"
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

  cluster_name = "${var.vault_cluster_name}"
  cluster_tag_name = "${var.vault_cluster_name}"

  health_check_path = "/"
  health_check_port = "${var.web_proxy_port}"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "consul_cluster" {
  source = "git::git@github.com:hashicorp/terraform-google-consul.git//modules/consul-cluster?ref=v0.2.0"

  gcp_region = "${var.gcp_region}"

  cluster_name = "${var.consul_server_cluster_name}"
  cluster_tag_name = "${var.consul_server_cluster_name}"
  cluster_size = "${var.consul_server_cluster_size}"

  source_image = "${var.consul_server_source_image}"
  machine_type = "${var.consul_server_machine_type}"

  startup_script = "${data.template_file.startup_script_consul.rendered}"

  # In a production setting, we strongly recommend only launching a Consul Server cluster as private nodes.
  # Note that the only way to reach private nodes via SSH is to first SSH into another node that is not private.
  assign_public_ip_addresses = false

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
