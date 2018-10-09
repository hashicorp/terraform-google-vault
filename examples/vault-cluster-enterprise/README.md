# Vault Cluster Enterprise Example 

This example deploys a publicly accessible [Vault](https://www.hashicorp.com/products/vault) Enterprise cluster in [GCP](https://cloud.google.com/)
fronted by a Regional External Load Balancer using the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) and [vault-lb-fr](
/modules/vault-lb-fr) modules. In this example we have also enabled the Vault Enterprise Auto Unseal features.

For an example of a private Vault cluster that is accessible only from inside the Google
Cloud VPC, see [vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private). **Deploying Vault in a publicly accessible way
should be avoided if possible due to the increased security exposure. However, it may be unavoidable, if, for example,
Vault is your system of record for identity.**. 

The Vault cluster uses [Consul](https://www.consul.io/) as a storage backend, so this example also deploys a separate
Consul server cluster using the [consul-cluster module](
https://github.com/hashicorp/terraform-google-consul/tree/master/modules/consul-cluster) from the Consul GCP Module.

You will need to create a [Google Image](https://cloud.google.com/compute/docs/images) that has the Vault and Consul
Enterprise versions installed, which you can do using the [vault-consul-image example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image)). Keep in mind, you must specify
the Vault & Consul Enterprise download URLs using the `VAULT_DOWNLOAD_URL` and `CONSUL_DOWNLOAD_URL` environment variables respectively.

Note that a Google Load Balancer requires a Health Check to confirm that the Vault nodes are healthy, but at this time,
Google Cloud only supports [associating HTTP Health Checks with a Target Pool](
https://github.com/terraform-providers/terraform-provider-google/issues/18), not HTTPS Health Checks. The recommended
workaround is to run a separate proxy server that listens over HTTP and forwards requests to the HTTPS Vault endpoint.
We accomplish this by using the [run-nginx](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-nginx) module to run the web server. 

For more info on how the Vault cluster works, check out the [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster) documentation.

**Note:** This example will automatically create a Google Cloud KMS key. You can disable this behaviour by setting the `var.create_kms_crypto_key` variable to false. Crypto Keys cannot be deleted from Google Cloud Platform, however their versions can. Terraform by default will erase all
Crypto Key versions when destroying the resource making any data encrypted by the key unrecoverable. For this reason we recommend reusing an
existing Cloud KMS key in production.

## Quick start

To deploy a Vault Cluster:

1. `git clone` this repo to your computer.
1. Build a Vault and Consul Enterprise Google Image. See the [vault-consul-image example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image) documentation
   for instructions. Make sure to note down the ID of the Google Image.
1. Install [Terraform](https://www.terraform.io/).
1. Make sure your local environment is authenticated to Google Cloud.
1. Open `variables.tf` and fill in any variables that don't have a default, including putting your Google Image ID into
   the `vault_source_image` and `consul_server_source_image` variables. Alternatively, initialize the variables by creating
   a `terraform.tfvars` file.
1. Add your Vault Enterprise license key the `vault-license.hclic`. **Note: That in production we recommend encrypting this key. See below for more information.** 
1. Run `terraform init`.
1. Run `terraform plan`.
1. If the plan looks good, run `terraform apply`.
1. To enable other Compute Instances in the same GCP Project to access the Vault Cluster, edit the `main.tf` file to 
   modify the `allowed_inbound_tags_api` variables. To allow arbitary IP addresses to access the Vault cluster from
   within the VPC, modify the `allowed_inbound_cidr_blocks_api` variable.
   
To see how to connect to the Vault cluster, initialize it, and start reading and writing secrets, head over to the 
[How do you use the Vault cluster?](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster#how-do-you-use-the-vault-cluster) docs.

## Encrypting your Vault Enterprise license

By default this example deploys unencrypted Vault Enterprise license keys directly in the startup scripts using the Terraform `file()` function.
In real-world production usage, we recommend first encrypting your license keys locally using the Cloud KMS tools and then decrypting them
directly on the instances.

This can easily be achieved locally using the following code snippet:

```bash
$ gcloud kms encrypt --keyring=keyring-example --key=example-key --location=global --plaintext-file=vault-license.hclic --ciphertext-file=vault-license.hclic.env
```

And during boot, directly in the `startup-script-vault-enterprise.sh` startup script:

```bash
$ gcloud kms decrypt --keyring=keyring-example --key=example-key --location=global --ciphertext-file=/opt/vault/vault-license.hclic.enc --plaintext-file=/opt/vault/vault-license.hclic
$ vault write /sys/license "text=$(cat /opt/vault/vault-license.hclic)"
```

You should then update the `startup-script-vault-enterprise.sh` file.
