# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These parameters must be supplied when consuming this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "The name of the GCP Project where all resources will be launched."
}

variable "gcp_region" {
  description = "The Region in which all GCP resources will be launched."
}

variable "subnet_ip_cidr_range" {
  description = "The cidr range for the subnetwork. Ex.: 10.1.0.0/16"
}

variable "bastion_server_name" {
  description = "The name of the bastion server that can reach the private vault cluster"
}

variable "vault_cluster_name" {
  description = "The name of the Vault Server cluster. All resources will be namespaced by this value. E.g. vault-server-prod"
}

variable "vault_source_image" {
  description = "The Google Image used to launch each node in the Vault Server cluster."
}

variable "vault_cluster_machine_type" {
  description = "The machine type of the Compute Instance to run for each node in the Vault cluster (e.g. n1-standard-1)."
}

variable "consul_server_cluster_name" {
  description = "The name of the Consul Server cluster. All resources will be namespaced by this value. E.g. consul-server-prod"
}

variable "consul_server_source_image" {
  description = "The Google Image used to launch each node in the Consul Server cluster."
}

variable "consul_server_machine_type" {
  description = "The machine type of the Compute Instance to run for each node in the Consul Server cluster (e.g. n1-standard-1)."
}

# Vault Auto Unseal Variables

variable "vault_auto_unseal_key_project_id" {
  description = "The GCP Project ID to use for the Auto Unseal feature."
}

variable "vault_auto_unseal_key_region" {
  description = "The GCP Region to use for the Auto Unseal feature."
}

variable "vault_auto_unseal_key_ring" {
  description = "The GCP Cloud KMS Key Ring to use for the Auto Unseal feature."
}

variable "vault_auto_unseal_crypto_key_name" {
  description = "The GCP Cloud KMS Crypto Key to use for the Auto Unseal feature. Note: if creating a new key using var.create_kms_crypto_key then use this key."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "network_name" {
  description = "The name of the VPC Network where all resources should be created."
  default     = "default"
}

variable "additional_allowed_inbound_tags_api" {
  type        = "list"
  description = "A list of additional tags that GCP project resources can have to be permitted access to the Vault API."
  default     = []
}

variable "gcs_bucket_location" {
  description = "The location of the Google Cloud Storage Bucket where Vault secrets will be stored. For details, see https://goo.gl/hk63jH."
  default     = "US"
}

variable "gcs_bucket_class" {
  description = "The Storage Class of the Google Cloud Storage Bucket where Vault secrets will be stored. Must be one of MULTI_REGIONAL, REGIONAL, NEARLINE, or COLDLINE. For details, see https://goo.gl/hk63jH."
  default     = "MULTI_REGIONAL"
}

variable "gcs_bucket_force_destroy" {
  description = "If true, Terraform will delete the Google Cloud Storage Bucket even if it's non-empty. WARNING! Never set this to true in a production setting. We only have this option here to facilitate testing."
  default     = true
}

variable "vault_cluster_size" {
  description = "The number of nodes to have in the Vault Server cluster. We strongly recommended that you use either 3 or 5."
  default     = 3
}

variable "consul_server_cluster_size" {
  description = "The number of nodes to have in the Consul Server cluster. We strongly recommended that you use either 3 or 5."
  default     = 3
}

variable "web_proxy_port" {
  description = "The port at which the HTTP proxy server will listen for incoming HTTP requests that will be forwarded to the Vault Health Check URL. We must have an HTTP proxy server to work around the limitation that GCP only permits Health Checks via HTTP, not HTTPS."
  default     = "8000"
}

variable "root_volume_disk_size_gb" {
  description = "The size, in GB, of the root disk volume on each Consul node."
  default     = 30
}

variable "root_volume_disk_type" {
  description = "The GCE disk type. Can be either pd-ssd, local-ssd, or pd-standard"
  default     = "pd-standard"
}

variable "enable_vault_ui" {
  description = "If true, enable the Vault UI"
  default     = true
}
