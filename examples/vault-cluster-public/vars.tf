# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These parameters must be supplied when consuming this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "gcp_project" {
  description = "The name of the GCP Project where all resources will be launched."
}

variable "gcp_region" {
  description = "The region in which all GCP resources will be launched."
}

variable "gcp_zone" {
  description = "The region in which all GCP resources will be launched."
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

# ---------------------------------------------------------------------------------------------------------------------
//# ENVIRONMENT VARIABLES
//# Define these secrets as environment variables
//# ---------------------------------------------------------------------------------------------------------------------
//
//# AWS_ACCESS_KEY_ID
//# AWS_SECRET_ACCESS_KEY
//
//# ---------------------------------------------------------------------------------------------------------------------
//# REQUIRED PARAMETERS
//# You must provide a value for each of these parameters.
//# ---------------------------------------------------------------------------------------------------------------------
//
//variable "ami_id" {
//  description = "The ID of the AMI to run in the cluster. This should be an AMI built from the Packer template under examples/vault-consul-ami/vault-consul.json. If no AMI is specified, the template will 'just work' by using the example public AMIs. WARNING! Do not use the example AMIs in a production setting!"
//  default = ""
//}
//
//variable "s3_bucket_name" {
//  description = "The name of an S3 bucket to create and use as a storage backend. Note: S3 bucket names must be *globally* unique."
//}
//
//variable "create_dns_entry" {
//  description = "If set to true, this module will create a Route 53 DNS A record for the ELB in the var.hosted_zone_id hosted zone with the domain name in var.domain_name."
//}
//
//variable "hosted_zone_domain_name" {
//  description = "The domain name of the Route 53 Hosted Zone in which to add a DNS entry for Vault (e.g. example.com). Only used if var.create_dns_entry is true."
//}
//
//variable "vault_domain_name" {
//  description = "The domain name to use in the DNS A record for the Vault ELB (e.g. vault.example.com). Make sure that a) this is a domain within the var.hosted_zone_domain_name hosted zone and b) this is the same domain name you used in the TLS certificates for Vault. Only used if var.create_dns_entry is true."
//}
//
//variable "ssh_key_name" {
//  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# OPTIONAL PARAMETERS
//# These parameters have reasonable defaults.
//# ---------------------------------------------------------------------------------------------------------------------
//
//variable "aws_region" {
//  description = "The AWS region to deploy into (e.g. us-east-1)."
//  default     = "us-east-1"
//}
//
//variable "vault_cluster_name" {
//  description = "What to name the Vault server cluster and all of its associated resources"
//  default     = "vault-example"
//}
//
//variable "consul_cluster_name" {
//  description = "What to name the Consul server cluster and all of its associated resources"
//  default     = "consul-example"
//}
//
//variable "vault_cluster_size" {
//  description = "The number of Vault server nodes to deploy. We strongly recommend using 3 or 5."
//  default     = 3
//}
//
//variable "consul_cluster_size" {
//  description = "The number of Consul server nodes to deploy. We strongly recommend using 3 or 5."
//  default     = 3
//}
//
//variable "vault_instance_type" {
//  description = "The type of EC2 Instance to run in the Vault ASG"
//  default     = "t2.micro"
//}
//
//variable "consul_instance_type" {
//  description = "The type of EC2 Instance to run in the Consul ASG"
//  default     = "t2.micro"
//}
//
//variable "consul_cluster_tag_key" {
//  description = "The tag the Consul EC2 Instances will look for to automatically discover each other and form a cluster."
//  default     = "consul-servers"
//}
//
//variable "force_destroy_s3_bucket" {
//  description = "If you set this to true, when you run terraform destroy, this tells Terraform to delete all the objects in the S3 bucket used for backend storage. You should NOT set this to true in production or you risk losing all your data! This property is only here so automated tests of this blueprint can clean up after themselves."
//  default     = false
//}
