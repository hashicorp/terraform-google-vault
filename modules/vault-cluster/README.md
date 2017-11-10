# Vault Cluster

This folder contains a [Terraform](https://www.terraform.io/) module that can be used to deploy a 
[Vault](https://www.vaultproject.io/) cluster in [Google Cloud](https://cloud.google.com/) on top of a Managed Instance
Group. This module is designed to deploy a [Google Image](https://cloud.google.com/compute/docs/images) 
that had Vault installed via the [install-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault) module in this Module.




## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "vault_cluster" {
  # Use version v0.0.1 of the vault-cluster module
  source = "github.com/hashicorp/terraform-google-vault//modules/vault-cluster?ref=v0.0.1"

  # Specify the ID of the Vault AMI. You should build this using the scripts in the install-vault module.
  source_image = "vault-consul-xxxxxx"
  
  # This module uses S3 as a storage backend
  gcs_bucket_name   = "${var.gcs_bucket_name}"
  
  # Configure and start Vault during boot. 
  startup_script = <<-EOF
                   #!/bin/bash
                   /opt/vault/bin/run-vault --gcs-bucket ${var.gcs_bucket_name} --tls-cert-file /opt/vault/tls/vault.crt.pem --tls-key-file /opt/vault/tls/vault.key.pem
                   EOF
  
  # ... See variables.tf for the other parameters you must define for the vault-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the vault-cluster module. The double slash (`//`) is intentional 
  and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `source_image`: Use this parameter to specify the name of a Vault [Google Image](
  https://cloud.google.com/compute/docs/images) to deploy on each server in the cluster. You should install Vault in
  this Image using the scripts in the [install-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault) module.
  
* `gcs_bucket_name`: This module creates a [GCS](https://cloud.google.com/storage/) to use as a storage backend for Vault.
 
* `startup_script`: Use this parameter to specify a [Startup Script](https://cloud.google.com/compute/docs/startupscript)
  that each server will run during boot. This is where you can use the [run-vault script](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-vault) to configure
  and  run Vault. The `run-vault` script is one of the scripts installed by the [install-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault) 
  module. 

You can find the other parameters in [variables.tf](variables.tf).

Check out the [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) and [vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private)
examples for working sample code.





## How do you use the Vault cluster?

To use the Vault cluster, you will typically need to SSH to each of the Vault servers. If you deployed the
[vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) or [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) 
examples, the [vault-examples-helper.sh script](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-examples-helper/vault-examples-helper.sh) will do the 
tag lookup for you automatically (note, you must have the [Google Cloud SDK](https://cloud.google.com/sdk/) installed
locally):

```
> ../vault-examples-helper/vault-examples-helper.sh

The following Vault servers are running:

vault-7djC
vault-o81b
vault-lx92
```

### Initializing the Vault cluster

The very first time you deploy a new Vault cluster, you need to [initialize the 
Vault](https://www.vaultproject.io/intro/getting-started/deploy.html#initializing-the-vault). The easiest way to do 
this is to SSH to one of the servers that has Vault installed and run:

```
vault init

Key 1: 427cd2c310be3b84fe69372e683a790e01
Key 2: 0e2b8f3555b42a232f7ace6fe0e68eaf02
Key 3: 37837e5559b322d0585a6e411614695403
Key 4: 8dd72fd7d1af254de5f82d1270fd87ab04
Key 5: b47fdeb7dda82dbe92d88d3c860f605005
Initial Root Token: eaf5cc32-b48f-7785-5c94-90b5ce300e9b

Vault initialized with 5 keys and a key threshold of 3!
```

Vault will print out the [unseal keys](https://www.vaultproject.io/docs/concepts/seal.html) and a [root 
token](https://www.vaultproject.io/docs/concepts/tokens.html#root-tokens). This is the **only time ever** that all of 
this data is known by Vault, so you **MUST** save it in a secure place immediately! Also, this is the only time that 
the unseal keys should ever be so close together. You should distribute each one to a different, trusted administrator
for safe keeping in completely separate secret stores and NEVER store them all in the same place. 

In fact, a better option is to initialize Vault with [PGP, GPG, or 
Keybase](https://www.vaultproject.io/docs/concepts/pgp-gpg-keybase.html) so that each unseal key is encrypted with a
different user's public key. That way, no one, not even the operator running the `init` command can see all the keys
in one place:

```
vault init -pgp-keys="keybase:jefferai,keybase:vishalnayak,keybase:sethvargo"

Key 1: wcBMA37rwGt6FS1VAQgAk1q8XQh6yc...
Key 2: wcBMA0wwnMXgRzYYAQgAavqbTCxZGD...
Key 3: wcFMA2DjqDb4YhTAARAAeTFyYxPmUd...
...
```

See [Using PGP, GPG, and Keybase](https://www.vaultproject.io/docs/concepts/pgp-gpg-keybase.html) for more info.


### Unsealing the Vault cluster

Now that you have the unseal keys, you can [unseal Vault](https://www.vaultproject.io/docs/concepts/seal.html) by 
having 3 out of the 5 administrators (or whatever your key shard threshold is) do the following:

1. SSH to a Vault server.
1. Run `vault unseal`.
1. Enter the unseal key when prompted.
1. Repeat for each of the other Vault servers.

Once this process is complete, all the Vault servers will be unsealed and you will be able to start reading and writing
secrets. Note that if you are using a Load Balancer, your Load Balancer will only start routing to Vault servers once 
they are unsealed.


### Connecting to the Vault cluster to read and write secrets

There are three ways to connect to Vault:

1. [Access Vault from a Vault server](#access-vault-from-a-vault-server)
1. [Access Vault from other servers in the same Google Cloud project](#access-vault-from-other-servers-in-the-same-google-cloud-project)
1. [Access Vault from the public Internet](#access-vault-from-the-public-internet)


#### Access Vault from a Vault server

When you SSH to a Vault server, the Vault client is already configured to talk to the Vault server on localhost, so 
you can directly run Vault commands:

```
vault read secret/foo

Key                 Value
---                 -----
refresh_interval    768h0m0s
value               bar
```


#### Access Vault from other servers in the same Google Cloud project

To access Vault from a different server in the same GCP project, first make sure that the variable `allowed_inbound_tags_api`
specifies a [Google Tag](https://cloud.google.com/compute/docs/vpc/add-remove-network-tags) in use by the server that
should have Vault access. Alternatively, update the variable `allowed_inbound_cidr_blocks_api` to specify a list of 
CIDR-formatted IP address ranges that can access the Vault cluster. Note that, these must be private IP addresses,
unless the variable `assign_public_ip_addresses` is set to `true`, in which case the cluster will be publicly accessible
and any IP address is valid.

Next, on the server that wants to connect to Vault, you need to specify the URL of the Vault cluster. You 
could manually look up the Vault cluster's IP address, but since this module uses Consul not only as a [storage 
backend](https://www.vaultproject.io/docs/configuration/storage/consul.html) but also as a way to register [DNS 
entries](https://www.consul.io/docs/guides/forwarding.html), you can access Vault 
using a nice domain name instead, such as `vault.service.consul`.

To set this up, use the [install-dnsmasq 
module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-dnsmasq) on each server that 
needs to access Vault. This allows you to access Vault from your EC2 Instances as follows:

```
vault -address=https://vault.service.consul:8200 read secret/foo

Key                 Value
---                 -----
refresh_interval    768h0m0s
value               bar
```

You can configure the Vault address as an environment variable:

```
export VAULT_ADDR=https://vault.service.consul:8200
```

That way, you don't have to remember to pass the Vault address every time:

```
vault read secret/foo

Key                 Value
---                 -----
refresh_interval    768h0m0s
value               bar
```

Note that if you're using a self-signed TLS cert (e.g. generated from the [private-tls-cert 
module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/private-tls-cert)), you'll need to have the public key of the CA that signed that cert or you'll get 
an "x509: certificate signed by unknown authority" error. You could pass the certificate manually:
 
```
vault read -ca-cert=/opt/vault/tls/ca.crt.pem secret/foo

Key                 Value
---                 -----
refresh_interval    768h0m0s
value               bar
```

However, to avoid having to add the `-ca-cert` argument to every single call, you can use the [update-certificate-store 
module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/update-certificate-store) to configure the server to trust the CA.

Check out the [vault-cluster-private example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) for working sample code. Alternatively,
you may set the environment variable [VAULT_CACERT](https://www.vaultproject.io/docs/commands/environment.html).


#### Access Vault from the public Internet

We **strongly** recommend only running Vault in private subnets. That means it is not directly accessible from the 
public Internet, which reduces your surface area to attackers. If you need users to be able to access Vault from 
outside of Google Cloud, we recommend using VPN to connect to Google Cloud. 
 
If VPN is not an option, and Vault must be accessible from the public Internet, you can use the [vault-lb-fr 
module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-lb-fr) to deploy a regional external [Load Balancer](https://cloud.google.com/load-balancing/)
and have all your users access Vault via this Load Balancer:

```
vault -address=https://<LOAD_BALANCER_IP> read secret/foo
```

Where `LOAD_BALANCER_IP` is the IP address for your Load Balancer, such as `vault.example.com`. You can configure the
Vault address as an environment variable:

```
export VAULT_ADDR=https://vault.example.com
```

That way, you don't have to remember to pass the Vault address every time:

```
vault read secret/foo
```






## What's included in this module?

This module creates the following architecture:

![Vault architecture](https://github.com/hashicorp/terraform-google-vault/blob/master/_docs/architecture.png?raw=true)

This architecture consists of the following resources:

* [Managed Instance Group](#managed-instance-group)
* [GCS Bucket](#gcs-bucket)
* [Firewall Rules](#firewall-rules)


### Managed Instance Group

This module runs Vault on top of a zonal [Managed Instance Group](https://cloud.google.com/compute/docs/instance-groups/). 
Typically, you should run the Instance Group with 3 or 5 Compute Instances spread across multiple [Zones](
https://cloud.google.com/compute/docs/regions-zones/regions-zones), but regrettably, Terraform Managed Instance Groups
[only support a single zone](https://github.com/terraform-providers/terraform-provider-google/issues/45). Each of the
Compute Instances should be running a Google Image that has had Vault installed via the [install-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault)
module. You pass in the Google Image name to run using the `source_image` input parameter.


### GCS Bucket

This module creates a [GCS bucket](https://cloud.google.com/storage/docs/) that Vault can use as a storage backend. 
GCS is a good choice for storage because it provides outstanding durability (99.999999999%) and reasonable availability
(99.9%).  Unfortunately, GCS cannot be used for Vault High Availability coordination, so this module expects a separate
Consul server cluster to be deployed as a high availability backend.


### Firewall Rules

Network access to the Vault Compute Instances is governed by any VPC-level Firewall Rules, but in addition, this module
creates Firewall Rules to explicitly:
 
* Allow Vault API requests within the cluster 
* Allow inbound API requests from the desired tags or CIDR blocks
* Allow inbound Health Check requests, if applicable

Check out the [Security section](#security) for more details. 



## How do you roll out updates?

Unfortunately, this remains an open item. Unlike Amazon Web Services, Google Cloud does not allow you to control the
manner in which Compute Instances in a Managed Instance Group are updated, except that you can specify that either
all Instances should be immediately restarted when a Managed Instance Group's Instance Template is updated (by setting
the [update_strategy](https://www.terraform.io/docs/providers/google/r/compute_instance_group_manager.html#update_strategy)
of the Managed Instance Group to `RESTART`), or that nothing at all should happen (by setting the update_strategy to 
`NONE`).

While updating Consul, we must be mindful of always preserving a [quorum](https://www.consul.io/docs/guides/servers.html#removing-servers),
but neither of the above options enables a safe update. While updating Vault, we need the ability to terminate one 
Compute Instance at a time to avoid down time.

One possible option may be the use of GCP's [Rolling Updates Feature](https://cloud.google.com/compute/docs/instance-groups/updating-managed-instance-groups)
however this feature remains in Alpha and may not necessarily support our use case.

The most likely solution will involve writing a script that makes use of the [abandon-instances](https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/managed/abandon-instances)
and [resize](https://cloud.google.com/sdk/gcloud/reference/compute/instance-groups/managed/resize) GCP API calls. Using
these primitives, we can "abandon" Compute Instances from a Compute Instance Group (thereby removing them from the Group
but leaving them otherwise untouched), manually add new Instances based on an updated Instance Template that will 
automatically join the Consul cluster, make Consul API calls to our abandoned Instances to leave the Group, validate
that all new Instances are members of the cluster and then manually terminate the abandoned Instances.  

For now, you can perform this process manually, but needless to say, PRs are welcome!


## What happens if a node crashes?

There are two ways a Vault node may go down:
 
1. The Vault process may crash. In that case, `supervisor` should restart it automatically.
1. The Compute Instance running Vault stops, crashes, or is otherwise deleted. In that case, the Managed Instance Group
   will launch a replacement automatically.  In this case, the Vault node will automatically recover, however it will
   now be in a sealed state, so operators must manually unseal it before it can process traffic again.

## Gotchas

We strongly recommend that you set `assign_public_ip_addresses` to `false` so that your Vault nodes are NOT addressable
from the public Internet. But running private nodes creates a few gotchas:

- **Configure Private Google Access.** By default, the Google Cloud API is queried over the public Internet, but private
  Compute Instances have no access to the public Internet so how do they query the Google API? Fortunately, Google 
  enables a Subnet property where you can [access Google APIs from within the network](
  https://cloud.google.com/compute/docs/private-google-access/configure-private-google-access) and not over the public
  Internet. **Setting this property is outside the scope of this module, but private Vault servers will not work unless
  this is enabled, or they have public Internet access.**

- **SSHing to private Compute Instances.** When a Compute Instance is private, you can only SSH into it from within the
  network. This module does not give you any direct way to SSH to the private Compute Instances, so you must separately
  setup a means to enter the network, for example, by setting up a public Bastion Host.

- **Internet access for private Compute Instances.** If you do want your private Compute Instances to have Internet 
  access, then Google recommends [setting up your own network proxy or NAT Gateway](
  https://cloud.google.com/compute/docs/vpc/special-configurations#proxyvm).  

## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Encryption in transit](#encryption-in-transit)
1. [Encryption at rest](#encryption-at-rest)
1. [Dedicated instances](#dedicated-instances)
1. [Security groups](#security-groups)
1. [SSH access](#ssh-access)


### Encryption in transit

Vault uses TLS to encrypt its network traffic. For instructions on configuring TLS, have a look at the
[How do you handle encryption documentation](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-vault#how-do-you-handle-encryption).


### Encryption at rest

Vault servers keep everything in memory and do not write any data to the local hard disk. To persist data, Vault
encrypts it, and sends it off to its storage backends, so no matter how the backend stores that data, it is already
encrypted. Even so, by default, [GCE encrypts all data at rest](
https://cloud.google.com/compute/docs/disks/customer-supplied-encryption), a process managed by GCE without any
additional actions needed on your part. You can also provide your own encryption keys and GCE will use these to protect
the Google-generated keys used to encrypt and decrypt your on-disk data. By default, this Module uses GCS as a storage
backend.


### Firewall Rules

This module creates Firewall Rules that explicitly permit the minimum ports necessary for the Vault cluster to function.
See the Firewall Rules section above for details.
  
  

### SSH access

You can SSH to the Compute Instances using the [conventional methods offered by GCE](
https://cloud.google.com/compute/docs/instances/connecting-to-instance). Google [strongly recommends](
https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys) that you connect to an Instance [from your web
browser](https://cloud.google.com/compute/docs/instances/connecting-to-instance#sshinbrowser) or using the [gcloud
command line tool](https://cloud.google.com/compute/docs/instances/connecting-to-instance#sshingcloud).

If you must manually manage your SSH keys, use the `custom_metadata` property to specify accepted SSH keys in the format
required by GCE. 





## What's NOT included in this module?

This module does NOT handle the following items, which you may want to provide on your own:

* [Consul](#consul)
* [Monitoring, alerting, log aggregation](#monitoring-alerting-log-aggregation)
* [VPCs, subnets, route tables](#vpcs-subnets-route-tables)
* [DNS entries](#dns-entries)


### Consul

This Module configures Vault to use Consul as a high availability storage backend. It assumes you already 
have Consul servers deployed in a separate cluster. We do not recommend co-locating Vault and Consul servers in the 
same cluster because:

1. Vault is a tool built specifically for security, and running any other software on the same server increases its
   surface area to attackers.
1. This Vault Module uses Consul as a high availability storage backend and both Vault and Consul keep their working 
   set in memory. That means you have two programs independently jockying for memory consumption on each server.

Check out the [Consul GCP Module](https://github.com/hashicorp/terraform-google-consul) for how to deploy a Consul 
server cluster in GCP. See the [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) and 
[vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) examples for sample code that shows how to run both a
Vault server cluster and Consul server cluster.


### Monitoring, alerting, log aggregation

This module does not include anything for monitoring, alerting, or log aggregation. All Compute Instance Groups and 
Compute Instances come with the option to use [Google StackDriver](https://cloud.google.com/stackdriver/), GCP's monitoring,
logging, and diagnostics platform that works with both GCP and AWS.

If you wish to install the StackDriver monitoring agent or logging agent, pass the desired installation instructions to
the `startup_script` property.


### VPCs, subnetworks, route tables

This module assumes you've already created your network topology (VPC, subnetworks, route tables, etc). By default,
it will use the "default" network for the Project you select, but you may specify custom networks via the `network_name`
property, or just use the default network topology created by GCP.


### DNS entries

This module does not create any DNS entries for Vault (e.g. with Cloud DNS).