# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_zone" {
  description = "All GCP resources will be launched in this Zone."
}

variable "cluster_name" {
  description = "The name of the Vault cluster (e.g. vault-stage). This variable is used to namespace all resources created by this module."
}

variable "cluster_tag_name" {
  description = "The tag name the Compute Instances will look for to automatically discover each other and form a cluster. TIP: If running more than one Vault cluster, each cluster should have its own unique tag name."
}

variable "machine_type" {
  description = "The machine type of the Compute Instance to run for each node in the cluster (e.g. n1-standard-1)."
}

variable "cluster_size" {
  description = "The number of nodes to have in the Vault cluster. We strongly recommended that you use either 3 or 5."
}

variable "source_image" {
  description = "The source image used to create the boot disk for a Vault node. Only images based on Ubuntu 16.04 LTS are supported at this time."
}

variable "startup_script" {
  description = "A Startup Script to execute when the server first boots. We recommend passing in a bash script that executes the run-vault script, which should have been installed in the Vault Google Image by the install-vault module."
}

variable "gcs_bucket_name" {
  description = "The name of the Google Storage Bucket where Vault secrets will be stored."
}

variable "gcs_bucket_location" {
  description = "The location of the Google Storage Bucket where Vault secrets will be stored. For details, see https://goo.gl/hk63jH."
}

variable "gcs_bucket_storage_class" {
  description = "The Storage Class of the Google Storage Bucket where Vault secrets will be stored. Must be one of MULTI_REGIONAL, REGIONAL, NEARLINE, or COLDLINE. For details, see https://goo.gl/hk63jH."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "instance_group_target_pools" {
  description = "To use a Load Balancer with the Vault cluster, you must populate this value. Specifically, this is the list of Target Pool URLs to which new Compute Instances in the Instance Group created by this module will be added. Note that updating the Target Pools attribute does not affect existing Compute Instances."
  type = "list"
  default = []
}

variable "cluster_description" {
  description = "A description of the Vault cluster; it will be added to the Compute Instance Template."
  default = ""
}

variable "assign_public_ip_addresses" {
  description = "If true, each of the Compute Instances will receive a public IP address and be reachable from the Public Internet (if Firewall rules permit). If false, the Compute Instances will have private IP addresses only. In production, this should be set to false."
  default = false
}

variable "network_name" {
  description = "The name of the VPC Network where all resources should be created."
  default = "default"
}

variable "custom_tags" {
  description = "A list of tags that will be added to the Compute Instance Template in addition to the tags automatically added by this module."
  type = "list"
  default = []
}

variable "service_account_scopes" {
  description = "A list of service account scopes that will be added to the Compute Instance Template in addition to the scopes automatically added by this module."
  type = "list"
  default = []
}

variable "service_account_email" {
  description = "The email of the service account for the instance template. If none is provided the google cloud provider project service account is used."
  default     = ""
}

variable "instance_group_update_strategy" {
  description = "The update strategy to be used by the Instance Group. IMPORTANT! When you update almost any cluster setting, under the hood, this module creates a new Instance Group Template. Once that Instance Group Template is created, the value of this variable determines how the new Template will be rolled out across the Instance Group. Unfortunately, as of August 2017, Google only supports the options 'RESTART' (instantly restart all Compute Instances and launch new ones from the new Template) or 'NONE' (do nothing; updates should be handled manually). Google does offer a rolling updates feature that perfectly meets our needs, but this is in Alpha (https://goo.gl/MC3mfc). Therefore, until this module supports a built-in rolling update strategy, we recommend using `NONE` and either using the alpha rolling updates strategy to roll out new Vault versions, or to script this using GCE API calls. If using the alpha feature, be sure you are comfortable with the level of risk you are taking on. For additional detail, see https://goo.gl/hGH6dd."
  default = "NONE"
}

variable "using_load_balancer" {
  description = "If you are using a load balancer with Vault, set this to true. If true, a Firewall Rule will be created that allows inbound Health Check traffic on var.api_port."
  default = false
}

# Metadata

variable "metadata_key_name_for_cluster_size" {
  description = "The key name to be used for the custom metadata attribute that represents the size of the Vault cluster."
  default = "cluster-size"
}

variable "custom_metadata" {
  description = "A map of metadata key value pairs to assign to the Compute Instance metadata."
  type = "map"
  default = {}
}

# Firewall Ports

variable "api_port" {
  description = "The port used by Vault to handle incoming API requests."
  default = 8200
}

variable "cluster_port" {
  description = "The port used by Vault for server-to-server communication."
  default = 8201
}

variable "allowed_inbound_cidr_blocks_api" {
  description = "A list of CIDR-formatted IP address ranges from which the Compute Instances will allow connections to Vault on the configured TCP Listener (see https://goo.gl/Equ4xP)"
  type = "list"
  default = ["0.0.0.0/0"]
}

variable "allowed_inbound_tags_api" {
  description = "A list of tags from which the Compute Instances will allow connections to Vault on the configured TCP Listener (see https://goo.gl/Equ4xP)"
  type = "list"
  default = []
}

# Disk Settings

variable "root_volume_disk_size_gb" {
  description = "The size, in GB, of the root disk volume on each Vault node."
  default = 30
}

variable "root_volume_disk_type" {
  description = "The GCE disk type. Can be either pd-ssd, local-ssd, or pd-standard"
  default = "pd-standard"
}

# Google Storage Bucket Settings

variable "gcs_bucket_force_destroy" {
  description = "If true, Terraform will delete the Google Cloud Storage Bucket even if it's non-empty. WARNING! Never set this to true in a production setting. We only have this option here to facilitate testing."
  default = false
}

variable "gcs_bucket_predefined_acl" {
  description = "The canned GCS Access Control List (ACL) to apply to the GCS Bucket. For a full list of Predefined ACLs, see https://cloud.google.com/storage/docs/access-control/lists."
  default = "projectPrivate"
}
