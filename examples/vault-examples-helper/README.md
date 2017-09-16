# Vault Examples Helper

This folder contains a helper script called `vault-examples-helper.sh` for working with the 
[vault-cluster-private](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private) and [vault-cluster-public](https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-public) 
examples. After running `terraform apply` on one of the examples, if you run  `vault-examples-helper.sh`, it will 
automatically:

1. Wait for the Vault server cluster to come up.
1. Print out the IP addresses of the Vault servers.
1. Print out some example commands you can run against your Vault servers.

Please note that this helper script only works with the root example in this repo because that is the only example where
Vault servers are publicly accessible by default. This is OK for testing and learning, but for production usage, we strongly 
recommend running Vault servers that are not accessible from the public Internet.
