# Root Example 

This folder contains files for the example Terraform configuration contained in the "root" of this repo.

That example deploys a publicly accessible [Vault](https://www.vaultproject.io/) cluster in [GCP](https://cloud.google.com/)
using the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) module. For an example of a private Vault cluster that is accessible
only from inside the Google Cloud VPC, see [vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private). **Do NOT use this
example in a production setting. Deploying Vault as a publicly accessible cluster is not recommended in production; we
do it here only to provide a convenient quick start experience.**. 

The Vault cluster uses [Consul](https://www.consul.io/) as a storage backend, so this example also deploys a separate
Consul server cluster using the [consul-cluster module](
https://github.com/hashicorp/terraform-google-consul/tree/master/modules/consul-cluster) from the Consul GCP Module.

You will need to create a [Google Image](https://cloud.google.com/compute/docs/images) that has Vault and Consul
installed, which you can do using the [vault-consul-image example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image)).  

For more info on how the Vault cluster works, check out the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) documentation.


## Quick start

To deploy a Vault Cluster:

1. `git clone` this repo to your computer.
1. Build a Vault and Consul Google Image. See the [vault-consul-image example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image) documentation
   for instructions. Make sure to note down the ID of the Google Image.
1. Install [Terraform](https://www.terraform.io/).
1. Make sure you local environment is authenticated to Google Cloud.
1. Open `variables.tf` and fill in any variables that don't have a default, including putting your Google Image ID into
   the `vault_source_image` and `consul_server_source_image` variables.
1. Run `terraform init`.
1. Run `terraform plan`.
1. If the plan looks good, run `terraform apply`.
1. Run the [vault-examples-helper.sh script](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-examples-helper/vault-examples-helper.sh) to 
   print out the names and IP addresses of the Vault servers and some example commands you can run to interact with the
   cluster: `../vault-examples-helper/vault-examples-helper.sh`.
   
To see how to connect to the Vault cluster, initialize it, and start reading and writing secrets, head over to the 
[How do you use the Vault cluster?](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster#how-do-you-use-the-vault-cluster) docs.
