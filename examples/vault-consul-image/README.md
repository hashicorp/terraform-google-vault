# Vault and Consul Google Image

This folder shows an example of how to use the [install-vault module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault) from this Module and 
the [install-consul](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul)
and [install-dnsmasq](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-dnsmasq) modules
from the Consul GCP Module with [Packer](https://www.packer.io/) to create a [Google Image](
https://cloud.google.com/compute/docs/images) that has Vault and Consul installed on top of:
 
1. Ubuntu 16.04

You can use this Google Image to deploy a [Vault cluster](https://www.vaultproject.io/) by using the [vault-cluster
module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster). This Vault cluster will use Consul as its storage backend, so you can also use the 
same Google Image to deploy a separate [Consul server cluster](https://www.consul.io/) by using the [consul-cluster 
module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/consul-cluster). 

Check out the [vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) and 
[vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) examples for working sample code. For more info on Vault 
installation and configuration, check out the [install-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault) documentation.



## Quick start

To build the Vault and Consul Google Image:

1. `git clone` this repo to your computer.

1. Install [Packer](https://www.packer.io/).

1. Configure your environment's Google credentials using the [Google Cloud SDK](https://cloud.google.com/sdk/).

1. Use the [private-tls-cert module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/private-tls-cert) to generate a CA cert and public and private keys for a
   TLS cert:

    1. Set the `dns_names` parameter to `vault.service.consul`. If you're using the [vault-cluster-public
       example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) and want a public domain name (e.g. `vault.example.com`), add that
       domain name here too.
    1. Set the `ip_addresses` to `127.0.0.1`.
    1. For production usage, you should take care to protect the private key by encrypting it (see [Using TLS
       certs](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/private-tls-cert#using-tls-certs) for more info).

1. Update the `variables` section of the `vault-consul.json` Packer template to configure the Project ID, Google Cloud Zone,
   and Consul and Vault versions you wish to use. Alternatively, you can pass in these values using `packer build vault-consul.json -var var_name=var_value ...`

1. Run `packer build vault-consul.json`.

When the build finishes, it will output the ID of the new Google Image. To see how to deploy this Image, check out the 
[vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) and [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) 
examples.




## Creating your own Packer template for production usage

When creating your own Packer template for production usage, you can copy the example in this folder more or less 
exactly, except for one change: we recommend replacing the `file` provisioner with a call to `git clone` in the `shell` 
provisioner. Instead of:

```json
{
  "provisioners": [{
    "type": "file",
    "source": "{{template_dir}}/../../../terraform-google-vault",
    "destination": "/tmp"
  },{
    "type": "shell",
    "inline": [
      "/tmp/terraform-google-vault/modules/install-vault/install-vault --version {{user `vault_version`}}"
    ],
    "pause_before": "30s"
  }]
}
```

Your code should look more like this:

```json
{
  "provisioners": [{
    "type": "shell",
    "inline": [
      "git clone --branch <MODULE_VERSION> https://github.com/hashicorp/terraform-google-vault.git /tmp/terraform-google-vault",
      "/tmp/terraform-google-vault/modules/install-vault/install-vault --version {{user `vault_version`}}"
    ],
    "pause_before": "30s"
  }]
}
```

You should replace `<MODULE_VERSION>` in the code above with the version of this Module that you want to use (see
the [Releases Page](https://github.com/hashicorp/terraform-google-vault/releases) for all available versions). That's because for production usage, you should always
use a fixed, known version of this Module, downloaded from the official Git repo. On the other hand, when you're 
just experimenting with the Module, it's OK to use a local checkout of the Module, uploaded from your own 
computer.