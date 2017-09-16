# Public Vault Cluster Example 

This example deploys a publicly accessible [Vault](https://www.vaultproject.io/) cluster in [GCP](https://cloud.google.com/)
fronted by a Regional External Load Balancer using the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) and [vault-lb-fr](
/modules/vault-lb-fr) modules. For an example of a private Vault cluster that is accessible only from inside the Google
Cloud VPC, see [vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private). **Deploying Vault in a publicly accessible way
should be avoided if possible due to the increased security exposure. However, it may be unavoidable, if, for example,
Vault is your system of record for identity.**. 

The Vault cluster uses [Consul](https://www.consul.io/) as a storage backend, so this example also deploys a separate
Consul server cluster using the [consul-cluster module](
https://github.com/gruntwork-io/terraform-google-consul/tree/master/modules/consul-cluster) from the Consul GCP Module.

You will need to create a [Google Image](https://cloud.google.com/compute/docs/images) that has Vault and Consul
installed, which you can do using the [vault-consul-image example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image)).  

Note that a Google Load Balancer requires a Health Check to confirm that the Vault nodes are healthy, but at this time,
Google Cloud only supports [associating HTTP Health Checks with a Target Pool](
https://github.com/terraform-providers/terraform-provider-google/issues/18), not HTTPS Health Checks. The recommended
workaround is to run a separate proxy server that listens over HTTP and forwards requests to the HTTPS Vault endpoint.
We accomplish this by using the [run-nginx](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-nginx) module to run the web server. 

For more info on how the Vault cluster works, check out the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) documentation.


## Quick start

To deploy a Vault Cluster:

1. `git clone` this repo to your computer.
1. Build a Vault and Consul Google Image. See the [vault-consul-image example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image) documentation
   for instructions. Make sure to note down the ID of the Google Image.
1. Install [Terraform](https://www.terraform.io/).
1. Make sure your local environment is authenticated to Google Cloud.
1. Open `variables.tf` and fill in any variables that don't have a default, including putting your Goolge Image ID into
   the `vault_source_image` and `consul_server_source_image` variables.
1. Run `terraform init`.
1. Run `terraform plan`.
1. If the plan looks good, run `terraform apply`.
1. To enable other Compute Instances in the same GCP Project to access the Vault Cluster, edit the `main.tf` file to 
   modify the `allowed_inbound_tags_api` variables. To allow arbitary IP addresses to access the Vault cluster from
   within the VPC, modify the `allowed_inbound_cidr_blocks_api` variable.
   
To see how to connect to the Vault cluster, initialize it, and start reading and writing secrets, head over to the 
[How do you use the Vault cluster?](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster#how-do-you-use-the-vault-cluster) docs.
