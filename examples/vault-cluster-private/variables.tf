# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These parameters must be supplied when consuming this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_project" {
  description = "The name of the GCP Project where all resources will be launched."
}

variable "gcp_region" {
  description = "The Region in which all GCP resources will be launched."
}

variable "vault_cluster_name" {
  description = "The name of the Consul Server cluster. All resources will be namespaced by this value. E.g. consul-server-prod"
}

variable "vault_source_image" {
  description = "The Google Image used to launch each node in the Consul Server cluster."
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcs_bucket_location" {
  description = "The location of the Google Cloud Storage Bucket where Vault secrets will be stored. For details, see https://goo.gl/hk63jH."
  default = "US"
}

variable "gcs_bucket_class" {
  description = "The Storage Class of the Google Cloud Storage Bucket where Vault secrets will be stored. Must be one of MULTI_REGIONAL, REGIONAL, NEARLINE, or COLDLINE. For details, see https://goo.gl/hk63jH."
  default = "MULTI_REGIONAL"
}

variable "gcs_bucket_force_destroy" {
  description = "If true, Terraform will delete the Google Cloud Storage Bucket even if it's non-empty. WARNING! Never set this to true in a production setting. We only have this option here to facilitate testing."
  default = true
}

variable "vault_cluster_size" {
  description = "The number of nodes to have in the Vault Server cluster. We strongly recommended that you use either 3 or 5."
  default = 3
}

variable "consul_server_cluster_size" {
  description = "The number of nodes to have in the Consul Server cluster. We strongly recommended that you use either 3 or 5."
  default = 3
}

variable "root_volume_disk_size_gb" {
  description = "The size, in GB, of the root disk volume on each Consul node."
  default = 30
}

variable "root_volume_disk_type" {
  description = "The GCE disk type. Can be either pd-ssd, local-ssd, or pd-standard"
  default = "pd-standard"
}

variable "enable_vault_ui" {
  description = "If true, enable the Vault UI"
  default = true
}