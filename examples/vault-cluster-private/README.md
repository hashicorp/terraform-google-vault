# Private Vault Cluster Example 

This example deploys a private [Vault](https://www.vaultproject.io/) cluster in [GCP](https://cloud.google.com/)
using the [vault-cluster](/modules/vault-cluster) module. For an example of a public Vault cluster that is accessible
from the public Internet, see [vault-cluster-public](/examples/vault-cluster-public). A private Vault cluster is only 
reachable from another Compute Instance, so this example does not provide any built-in way of reaching the Compute 
Instances that are launched. Instead, you will need to separately launch a public Compute Instance from which you can
access these nodes.

The Vault cluster uses [Consul](https://www.consul.io/) as a storage backend, so this example also deploys a separate
Consul server cluster using the [consul-cluster module](
https://github.com/gruntwork-io/terraform-google-consul/tree/master/modules/consul-cluster) from the Consul GCP Module.

You will need to create a [Google Image](https://cloud.google.com/compute/docs/images) that has Vault and Consul
installed, which you can do using the [vault-consul-image example](/examples/vault-consul-image)).  

For more info on how the Vault cluster works, check out the [vault-cluster](/modules/vault-cluster) documentation.


## Quick start

To deploy a Vault Cluster:

1. `git clone` this repo to your computer.
1. Build a Vault and Consul Google Image. See the [vault-consul-image example](/examples/vault-consul-image) documentation
   for instructions. Make sure to note down the ID of the Google Image.
1. Install [Terraform](https://www.terraform.io/).
1. Make sure you local environment is authenticated to Google Cloud.
1. Open `variables.tf` and fill in any variables that don't have a default, including putting your Google Image ID into
   the `vault_source_image` and `consul_server_source_image` variables. 
1. Run `terraform init`.
1. Run `terraform plan`.
1. If the plan looks good, run `terraform apply`.
1. To enable other Compute Instances in the same GCP Project to access the Vault Cluster, edit the `main.tf` file to 
   modify the `allowed_inbound_tags_api` variables. To allow arbitary IP addresses to access the Vault cluster from
   within the VPC, modify the `allowed_inbound_cidr_blocks_api` variable.
   
To see how to connect to the Vault cluster, initialize it, and start reading and writing secrets, head over to the 
[How do you use the Vault cluster?](/modules/vault-cluster#how-do-you-use-the-vault-cluster) docs.
