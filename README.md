[![Maintained by Gruntwork.io](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)](https://gruntwork.io/?ref=repo_gcp_vault)
# Vault for Google Cloud Platform (GCP)

This repo contains a Terraform Module for how to deploy a [Vault](https://www.vaultproject.io/) cluster on
[GCP](https://cloud.google.com/) using [Terraform](https://www.terraform.io/). Vault is an open source tool for managing
secrets. This Module uses [GCS](https://cloud.google.com/storage/) as a [storage backend](
https://www.vaultproject.io/docs/configuration/storage/index.html) and a [Consul](https://www.consul.io)
server cluster as a [high availability backend](https://www.vaultproject.io/docs/concepts/ha.html):

![Vault architecture](https://github.com/hashicorp/terraform-google-vault/blob/master/_docs/architecture.png?raw=true)

This Module includes the following submodules:

* [install-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault): This module can be used to install Vault. It can be used in a
  [Packer](https://www.packer.io/) template to create a Vault
  [Google Image](https://cloud.google.com/compute/docs/images).

* [run-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-vault): This module can be used to configure and run Vault. It can be used in a
  [Startup Script](https://cloud.google.com/compute/docs/startupscript)
  to fire up Vault while the server is booting.

* [install-nginx](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-nginx): This module can be used to install Nginx. It can be used in a
  [Packer](https://www.packer.io/) template to create a Vault
  [Google Image](https://cloud.google.com/compute/docs/images). This module is only necessary when using
  a Load Balancer which requires a Health Checker.

* [run-nginx](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-vault): This module can be used to configure and run nginx. It can be used in a
  [Startup Script](https://cloud.google.com/compute/docs/startupscript)
  to launch nginx while the server is booting.

* [vault-cluster](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster): Terraform code to deploy a cluster of Vault servers using a [Managed Instance
  Group](https://cloud.google.com/compute/docs/instance-groups/).

* [vault-lb-fr](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-lb-fr): Configures a [Regional External Load Balancer](https://cloud.google.com/compute/docs/load-balancing/)
  in front of Vault if you need to access it from the public Internet.

* [private-tls-cert](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/private-tls-cert): Generate a private TLS certificate for use with a private Vault
  cluster.

* [update-certificate-store](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/update-certificate-store): Add a trusted, CA public key to an OS's
  certificate store. This allows you to establish TLS connections to services that use this TLS certs signed by this
  CA without getting x509 certificate errors.




## What's a Terraform Module?

A Terraform Module refers to a self-contained packages of Terraform configurations that are managed as a group. This repo
is a Terraform Module and contains many "submodules" which can be composed together to create useful infrastructure patterns.



## Who maintains this Module?

This Module is maintained by [Gruntwork](http://www.gruntwork.io/). If you're looking for help or commercial
support, send an email to [modules@gruntwork.io](mailto:modules@gruntwork.io?Subject=Vault%20Module).
Gruntwork can help with:

* Setup, customization, and support for this Terraform Module.
* Commercially supported Modules for other types of infrastructure, such as VPCs, Docker clusters, databases, and continuous integration.
* Modules that meet compliance requirements, such as HIPAA.
* Consulting & Training on AWS, Google Cloud, Terraform, and DevOps.



## How do you use this Module?

This Module adheres to [Terraform Module Conventions](https://www.terraform.io/docs/modules/index.html) and has the
following folder structure:

* [modules](https://github.com/hashicorp/terraform-google-vault/tree/master/modules): This folder contains the reusable code for this Terraform Module, broken down into one or more submodules.
* [examples](https://github.com/hashicorp/terraform-google-vault/tree/master/examples): This folder contains examples of how to use the submodules.
* [test](https://github.com/hashicorp/terraform-google-vault/tree/master/test): Automated tests for the submodules and examples.

Click on each of the submodules above for more details.

To deploy Vault with this Terraform Module, you will need to deploy two separate clusters: one to run
[Consul](https://www.consul.io/) servers (which Vault uses as a [high availability
backend](https://www.vaultproject.io/docs/concepts/ha.html)) and one to run Vault servers.

To deploy the Consul server cluster, use the [Consul GCP Module](https://github.com/hashicorp/terraform-google-consul).

To deploy the Vault cluster:

1. Create a Google Image that has Vault installed (using the [install-vault module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/install-vault)) and the Consul
   agent installed (using the [install-consul
   module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-consul)). Here is an
   [example Packer template](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image). Google Cloud does not allow the creation of public Images
   so you _must_ create this Image on your own to proceed!

1. Deploy that Image across a Managed Instance Group using the Terraform [vault-cluster-module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster).

1 TODO ACCESSING THE CLUSTER THROUGH SSH 

1. Execute the [run-consul script](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/run-consul)
   with the `--client` flag during boot on each Instance to have the Consul agent connect to the Consul server cluster.

1. Execute the [run-vault](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/run-vault) script during boot on each Instance to create the Vault cluster.

1. If you only need to access Vault from inside your GCP account (recommended), run the [install-dnsmasq
   module](https://github.com/hashicorp/terraform-google-consul/tree/master/modules/install-dnsmasq) on each server,
   and that server will be able to reach Vault using the Consul Server cluster as the DNS resolver (e.g. using an address
   like `vault.service.consul`). See the [vault-cluster-private example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) for working
   sample code.

1. If you need to access Vault from the public Internet, deploy the [vault-lb-fr module](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-lb-fr) and have
   all requests to Vault go through the Load Balancer. See the [vault-cluster-public example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public)
   for working sample code.

1. Head over to the [How do you use the Vault cluster?](https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster#how-do-you-use-the-vault-cluster) guide
   to learn how to initialize, unseal, and use Vault.



## Quick Start

See the [root-example](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/root-example) for the fastest way to try out this Module.



## How do I contribute to this Module?

Contributions are very welcome! Check out the [Contribution Guidelines](https://github.com/hashicorp/terraform-google-vault/tree/master/CONTRIBUTING.md) for instructions.



## How is this Module versioned?

This Terraform Module follows the principles of [Semantic Versioning](http://semver.org/). You can find each new release,
along with the changelog, in the [Releases Page](../../releases).

During initial development, the major version will be 0 (e.g., `0.x.y`), which indicates the code does not yet have a
stable API. Once we hit `1.0.0`, we will make every effort to maintain a backwards compatible API and use the MAJOR,
MINOR, and PATCH versions on each release to indicate any incompatibilities.



## License

This code is released under the Apache 2.0 License. Please see [LICENSE](https://github.com/hashicorp/terraform-google-vault/tree/master/LICENSE) and [NOTICE](https://github.com/hashicorp/terraform-google-vault/tree/master/NOTICE) for more
details.

Copyright &copy; 2017 Gruntwork, Inc.
