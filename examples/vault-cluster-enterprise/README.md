# Vault Cluster Enterprise Example

This example deploys a privately accessible [Vault](https://www.hashicorp.com/products/vault) Enterprise cluster
in [GCP](https://cloud.google.com/) fronted by a Regional External Load Balancer using the [vault-cluster][vault_cluster]
and [vault-lb-fr][vault_lb] modules. In this example we also enable the Auto Unseal feature.

For an example of a public Vault cluster that is accessible from outside the Google
Cloud VPC, see [vault-cluster root example](https://github.com/hashicorp/terraform-google-vault/tree/master/main.tf).
**Deploying Vault in a publicly accessible way should be avoided if possible due to the increased security exposure.
However, it may be unavoidable, if, for example, Vault is your system of record for identity.**.

The Vault cluster uses [Consul](https://www.consul.io/) as a storage backend, so this example also deploys a separate
Consul server cluster using the [consul-cluster module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/consul-cluster)
from the Consul GCP Module.

You will need to create a [Google Image](https://cloud.google.com/compute/docs/images) that has the Vault and Consul
Enterprise versions installed, which you can do using the [vault-consul-image example][image_example]. Keep in mind, to be able to run the Enterprise version of Vault or Consul, you must
specify the Vault & Consul Enterprise download URLs using the `VAULT_DOWNLOAD_URL` and `CONSUL_DOWNLOAD_URL`
environment variables respectively.

Note that a Google Load Balancer requires a Health Check to confirm that the Vault nodes are healthy, but at this time,
Google Cloud only supports [associating HTTP Health Checks with a Target Pool](
https://github.com/terraform-providers/terraform-provider-google/issues/18), not HTTPS Health Checks. The recommended
workaround is to run a separate proxy server that listens over HTTP and forwards requests to the HTTPS Vault endpoint.
We accomplish this by using the [run-nginx](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-nginx)
module to run the web server.

For more info on how the Vault cluster works, check out the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) documentation.

**Note:** This example will automatically create a Google Cloud KMS key. You can disable this behaviour by setting the `var.create_kms_crypto_key` variable to false. Crypto Keys cannot be deleted from Google Cloud Platform, however their versions can. Terraform will by default, erase all
Crypto Key versions when destroying the resource making any data encrypted by the key unrecoverable. For this reason we recommend reusing an
existing Cloud KMS key in production.

## Quick start

To deploy a Vault Cluster:

1. `git clone` this repo to your computer.
1. Build a Vault and Consul Enterprise Google Image. See the [vault-consul-image example][image_example] documentation
   for instructions. Make sure to note down the ID or family name of the Google Image.
1. Create a [Cloud KMS](https://cloud.google.com/kms/) key on your Google Cloud console. Make sure that the Cloud KMS
API is enabled, then create your key on the page `Cryptographic Keys`, which you will find under `Security`.
1. Install [Terraform](https://www.terraform.io/).
1. Make sure your local environment is authenticated to Google Cloud.
1. Open `variables.tf` and fill in any variables that don't have a default, including putting your Google Image ID into
   the `vault_source_image` and `consul_server_source_image` variables and the information about your Cloud KMS Key.
   Alternatively, initialize the variables by creating
   a `terraform.tfvars` file.
1. Run `terraform init`.
1. Run `terraform plan`.
1. If the plan looks good, run `terraform apply`.

To see how to connect to the Vault cluster, initialize it, and start reading and writing secrets, head over to the
[How do you use the Vault cluster?][how_to_use] docs.

## Applying your Vault Enterprise license

* Follow the steps in [Quick Start](#quick-start) to launch your Vault cluster.
* Ssh to one of the instances in the cluster
* Run `vault write /sys/license "text=YOUR LICENSE TEXT"`

## SSHing to the cluster

In this example, vault is launched to a private cluster, which means that the nodes do not have
public IP addresses and can't talk to the outside world directly. In order to be able to SSH to
a node, you can temporarily launch a Bastion Host, which is a public server within the same
subnetwork as the Vault cluster, so you can SSH to the bastion host, and then from the bastion
host you can SSH to private node using its private IP address.

### Seal

All data stored by Vault is encrypted with a Master Key which is not stored anywhere
and Vault only ever keeps in memory. When Vault first boots, it does not have the
Master Key in memory, and therefore it can access its storage, but it cannot decrypt
its own data. So you can't really do anything apart from unsealing it or checking
the server status. While Vault is at this state, we say it is "sealed".

Since vault uses [Shamir's Secret Sharing][shamir], which splits the master key into
pieces, running `vault operator unseal <unseal key>` adds piece by piece until there
are enough parts to reconstruct the master key. This is done on different machines in the
vault cluster for better security. When Vault is unsealed and it has the recreated
master key in memory, it can then be used to read the stored decryption keys, which
can decrypt the data, and then you can start performing other operations on Vault.

### Vault Auto-unseal

Vault has a feature that allows automatic unsealing via [GCP KMS][gcp_kms]. Without
auto unseal, Vault operators are expected to manually unseal each Vault node after
it boots, a cumbersome process that typically requires multiple Vault operators to each
enter a Vault master key shard. It was originally a Vault Enterprise feature, now available
on Vault open source too from version 1.0 onwards. It allows operators to delegate
the unsealing process to GCP, which is useful for failure situations where the server
has to restart and then it will be already unsealed, or for the creation of ephemeral
clusters. This process uses an GCP KMS key as a [seal wrap][seal_wrap]
mechanism: it encrypts and decrypts Vault's master key (and it does so with the
whole key, replacing the Shamir's Secret Sharing method).

For GCP, this feature is enabled by adding a `gcpckms` stanza at Vault's configuration.
This module takes this into consideration on the [`run-vault`][run_vault] binary, allowing
you to pass the following flags to it:
 * `--enable-auto-unseal`: Enables the GCP KMS Auto-unseal feature and adds the `gcpckms`
 stanza to the configuration
 * `--auto-unseal-key-project-id`
 * `--auto-unseal-key-region`
 * `--auto-unseal-key-ring`
 * `--auto-unseal-crypto-key-name`

In this example, like in other examples, we execute `run-vault` at the
[`startup script`][startup_script], which runs on boot for every node in the Vault
cluster. The value of these flags is passed to this script by Terraform, and have
to sent to Terraform as variables. This means that the GCP key has to be previously
manually created, we do this in this way because every key creation incurs a
[cost][kms_pricing].


[vault_cluster]: https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster
[vault_lb]: https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-lb-fr
[image_example]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image
[how_to_use]: https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster#how-do-you-use-the-vault-cluster
[kms_pricing]: https://cloud.google.com/kms/pricing
[run_vault]: https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-vault
[seal_wrap]: https://www.vaultproject.io/docs/enterprise/sealwrap/index.html
[gcp_kms]: https://www.vaultproject.io/docs/configuration/seal/gcpckms.html
[shamir]: https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing
[startup_script]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-enterprise/startup-script-vault-enterprise.sh
