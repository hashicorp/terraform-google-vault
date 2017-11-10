# Regional External Load Balancer for Vault

This folder contains a [Terraform](https://www.terraform.io/) module that can be used to deploy a regional external
[Network Load Balancer](https://cloud.google.com/compute/docs/load-balancing/network/) that fronts a [Vault](
https://www.vaultproject.io/) cluster in [Google Cloud](https://cloud.google.com/). 

In GCP, you do not actually create a new Network Load Balancer; rather you create a [Forwarding Rule](
https://cloud.google.com/compute/docs/load-balancing/network/forwarding-rules) which enables you to access an existing
region-wide Load Balancer already created by Google. This is why the name of this module is `vault-lb-fr`. In addition,
you must specify a [Target Pool](https://cloud.google.com/compute/docs/load-balancing/network/target-pools) that contains
all your "Targets", which are the Compute Instances to which the Load Balancer ultimately forwards traffic. Finally, you
must define a [Health Check](https://cloud.google.com/compute/docs/load-balancing/health-checks) that tells the Forwarding
Rule which of the Compute Instances in your Target Pool is healthy and able to receive traffic.

## When should you use this module?

We strongly recommend that you not expose Vault to the public Internet, however if you must, then the preferred way to
do so is to keep the Vault nodes themselves hidden from the public Internet, but to place a Load Balancer like the one
created by this module in front.

Some teams may wish to create an *internal* Load Balancer to have a single Vault endpoint. While there may be some use
cases that necessitate this, a 


## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "vault_lb" {
  # Use version v0.0.1 of the vault-cluster module
  source = "github.com/hashicorp/terraform-google-vault//modules/vault-lb-fr?ref=v0.0.1"

  # This is the tag name that the Vault Compute Instances use to automatically discover each other. Knowing this, we 
  # can create a Firewall Rule that permits access from the Load Balancer to the Vault Cluster
  cluster_tag_name   = "vault-test"
  
  # The Health Check will send an HTTP request to each of our Compute Instances. What path should it attempt to access
  # for a Vault Health check? Normally we'd want to use "/v1/sys/health?standbyok=true", however GCP only supports HTTP
  # Health Checks, not HTTPS Health Checks, so we must setup a forward proxy on the Vault server that forwards all inbound
  # traffic to the Vault Health Check endpoint. Therefore, what we specify here doesn't really matter as long as it's
  # non-empty.
  health_check_path = "/"
  
  # See the above comment. The forward proxy's port is 8000 by default
  health_check_port = 8000
  
  # ... See variables.tf for the other parameters you can define for the vault-lb-fr module
}
```

See [variables.tf](variables.tf) for additional information.