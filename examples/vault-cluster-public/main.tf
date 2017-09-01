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

  assign_public_ip_addresses = true

//  # Tell each Vault server to register in the ELB.
//  load_balancers = ["${module.vault_elb.load_balancer_name}"]
//
//  # To make testing easier, we allow requests from any IP address here but in a production deployment, we *strongly*
//  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
//
//  allowed_ssh_cidr_blocks            = ["0.0.0.0/0"]
//  allowed_inbound_cidr_blocks        = ["0.0.0.0/0"]
//  allowed_inbound_security_group_ids = []
//  ssh_key_name                       = "${var.ssh_key_name}"
}

# Render the Startup Script that will run on each Vault Instance on boot.
# This script will configure and start Vault.
data "template_file" "startup_script_vault" {
  template = ""
  #template = "${file("${path.module}/startup-script-vault.sh")}"

//  vars {
//    cluster_tag_name = "${var.consul_server_cluster_tag_name}"
//  }
}

//# ---------------------------------------------------------------------------------------------------------------------
//# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
//# This script will configure and start Vault
//# ---------------------------------------------------------------------------------------------------------------------
//
//data "template_file" "user_data_vault_cluster" {
//  template = "${file("${path.module}/user-data-vault.sh")}"
//
//  vars {
//    aws_region               = "${var.aws_region}"
//    s3_bucket_name           = "${var.s3_bucket_name}"
//    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
//    consul_cluster_tag_value = "${var.consul_cluster_name}"
//  }
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# DEPLOY THE ELB
//# ---------------------------------------------------------------------------------------------------------------------
//
//module "vault_elb" {
//  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
//  # to a specific version of the modules, such as the following example:
//  # source = "git::git@github.com:gruntwork-io/vault-aws-blueprint.git//modules/vault-elb?ref=v0.0.1"
//  source = "../../modules/vault-elb"
//
//  name = "${var.vault_cluster_name}"
//
//  vpc_id     = "${data.aws_vpc.default.id}"
//  subnet_ids = "${data.aws_subnet_ids.default.ids}"
//
//  # To make testing easier, we allow requests from any IP address here but in a production deployment, we *strongly*
//  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
//  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
//
//  # In order to access Vault over HTTPS, we need a domain name that matches the TLS cert
//  create_dns_entry = "${var.create_dns_entry}"
//  # Terraform conditionals are not short-circuiting, so we use join as a workaround to avoid errors when the
//  # aws_route53_zone data source isn't actually set: https://github.com/hashicorp/hil/issues/50
//  hosted_zone_id   = "${var.create_dns_entry ? join("", data.aws_route53_zone.selected.*.zone_id) : ""}"
//  domain_name      = "${var.vault_domain_name}"
//}
//
//# Look up the Route 53 Hosted Zone by domain name
//data "aws_route53_zone" "selected" {
//  count = "${var.create_dns_entry}"
//  name  = "${var.hosted_zone_domain_name}."
//}

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

//  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
//  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
//
//  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
//  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
//  ssh_key_name                = "${var.ssh_key_name}"
}

# This Startup Script will run at boot configure and start Consul on the Consul Server cluster nodes
data "template_file" "startup_script_consul" {
  template = "${file("${path.module}/startup-script-consul.sh")}"

  vars {
    cluster_tag_name   = "${var.consul_server_cluster_name}"
  }
}

//# ---------------------------------------------------------------------------------------------------------------------
//# DEPLOY THE CONSUL SERVER CLUSTER
//# ---------------------------------------------------------------------------------------------------------------------
//
//module "consul_cluster" {
//  source = "git::git@github.com:gruntwork-io/consul-aws-blueprint.git//modules/consul-cluster?ref=v0.0.5"
//
//  cluster_name  = "${var.consul_cluster_name}"
//  cluster_size  = "${var.consul_cluster_size}"
//  instance_type = "${var.consul_instance_type}"
//
//  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
//  cluster_tag_key   = "${var.consul_cluster_tag_key}"
//  cluster_tag_value = "${var.consul_cluster_name}"
//
//  ami_id    = "${var.ami_id == "" ? data.aws_ami.vault_consul.image_id : var.ami_id}"
//  user_data = "${data.template_file.user_data_consul.rendered}"
//
//  vpc_id     = "${data.aws_vpc.default.id}"
//  subnet_ids = "${data.aws_subnet_ids.default.ids}"
//
//  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
//  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
//
//  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
//  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
//  ssh_key_name                = "${var.ssh_key_name}"
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL SERVER WHEN IT'S BOOTING
//# This script will configure and start Consul
//# ---------------------------------------------------------------------------------------------------------------------
//
//data "template_file" "user_data_consul" {
//  template = "${file("${path.module}/user-data-consul.sh")}"
//
//  vars {
//    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
//    consul_cluster_tag_value = "${var.consul_cluster_name}"
//  }
//}
//
//# ---------------------------------------------------------------------------------------------------------------------
//# DEPLOY THE CLUSTERS IN THE DEFAULT VPC AND AVAILABILITY ZONES
//# Using the default VPC and subnets makes this example easy to run and test, but it means Consul and Vault are
//# accessible from the public Internet. In a production deployment, we strongly recommend deploying into a custom VPC
//# and private subnets. Only the ELB should run in the public subnets.
//# ---------------------------------------------------------------------------------------------------------------------
//
//data "aws_vpc" "default" {
//  default = true
//}
//
//data "aws_subnet_ids" "default" {
//  vpc_id = "${data.aws_vpc.default.id}"
//}
