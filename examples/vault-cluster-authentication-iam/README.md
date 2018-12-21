# Vault Cluster and Web Client with IAM Authentication Example

This example shows how to use IAM Service Accounts to authenticate to a
[vault cluster][vault_cluster].

Vault provides multiple ways to authenticate a human or machine to Vault, known as
[auth methods][auth_methods]. For example, a human can authenticate with a Username
& Password or with GitHub.

Among those methods you will find [GCP][gcp_auth]. The way it works is that Vault
understands GCP as a trusted third party, and relies on GCP itself for affirming
if an authentication source is a legitimate source or not.

There are currently two ways a GCP resource can authenticatate to Vault: `gce` and `iam`.
In this example, we demonstrate the [GCP IAM Auth Method][iam_auth].

For more info on how the Vault cluster works, check out the [vault-cluster][vault_cluster]
documentation. For an example on using the `gce` method, check out the
[vault-authentication-gce example][gce_example].

**Note**: This example launches a private vault cluster, meaning the nodes do not
have public IP addresses and cannot talk to the outside world. If you need to SSH
to your Vault cluster, check the [vault-cluster-private example][private_vault]
for instructions on how to launch a Bastion host in the same subnet and use it to
access the cluster.


## Running this example

You will need to create a [Google Image][google_image] that has Vault and Consul
installed, which you can do using the [vault-consul-image example][image_example].
All the GCE Instances in this example (including the GCE Instance that authenticates
to Vault) install [Dnsmasq][dnsmasq] (via the [install-dnsmasq module][dnsmasq_module])
so that all DNS queries for `*.consul` will be directed to the Consul Server cluster.
Because Consul has knowledge of all the Vault nodes (and in some cases, of other
services as well), this setup allows the instances to use Consul's DNS server for
service discovery, and thereby to discover the IP addresses of the Vault nodes.


## Quick start

1. `git clone` this repo to your computer.
1. Build a Vault and Consul Google Image. See the [vault-consul-image example][image_example]
  documentation for instructions. Make sure to note down the ID of the Google Image.
1. Install [Terraform](https://www.terraform.io/).
1. Make sure you local environment is authenticated to Google Cloud.
1. Open `variables.tf` and fill in any variables that don't have a default, including
  putting your Google Image ID into the `vault_source_image` and `consul_server_source_image`
  variables.
1. Run `terraform init`.
1. Run `terraform plan`.
1. If the plan looks good, run `terraform apply`.
1. Run `curl <web_client_public_ip>:8080` to check if the web server in the client
instance is fetching the secret from Vault correctly.

## IAM Auth

IAM auth is a process in which Vault leverages Google Cloud to identify and
authorize the IAM Service Account that originates the login request. Although
this method can be used with a Service Account attached to a GCE instance, Vault
also provides authentication based specifically on GCE Instance metadata. To
see more about the GCE method, please refer to the
[vault-cluster-authentication-gce example][gce_example].

The workflow is that the client trying to authenticate itself will need to
communicate with the Google API to generate a signed [JSON Web Token (JWT)][jwt],
which is a JSON-based open standard for creating access tokens. This process can
be quite cumbersome, but the Vault cli tool can do that for you. If you wish to
[generate the JWT yourself][generate_jwt] you can also use `curl` and `oauth2l`
or the `gcloud` tool. Once with signed JWT, the client can send it in its login
request along with the Vault Role it wishes to assume. Vault then verifies the JWT
with GCP as a proof-of-identity, checks against a predefined Vault authentication
role, then returns a client token that the client can use for making future
requests to Vault such as reading and writing secrets.

![auth diagram][auth_diagram]

It is important to notice that, to perform the authentication, certain scopes are
necessary when configuring the service account for the resources. For the IAM
method, both the authenticating Service Account and the Vault cluster's instance
template need to have the `cloud-platform` scope. Additionally, the Service Account
also needs to have the `roles/iam.serviceAccountTokenCreator` role, in order to
be able to create the signed JWT.

### Configuring the Vault server

Before we try to authenticate, we must be sure that the Vault Server is configured
properly and prepared to receive requests. First, we must make sure the Vault server
has been initialized (using `vault operator init`) and unsealed (either using
`vault operator unseal` or the [auto-unsealing feature][auto_unseal]).
Next, we must enable Vault to support the GCP auth method (using `vault auth enable gcp`).
Finally, we must define the correct Vault Policies and Roles to declare who will
have access to which resources in Vault.

[Policies][policies_doc] are rules that grant or forbid access and actions to
certain paths in Vault. With one or more policies on hand, you can then finally
create the authentication role.

When you create a Role in Vault, you define the Policies that are attached to that
Role, how principals who assume that Role will authenticate and other parameters
related to the authentication of that role such as when does the token issued by
a successful attempt will expire. When your Role uses the IAM GCP Auth method,
you also specify which Service Accounts are bound this role and allowed to
authenticate.

In our example we create a simple Vault Policy that allows writing and reading from
secrets in the path `secret` namespaced with the prefix `example_`, and then create
a Vault Role that allows authentication from the Service Account we create in
our Terraform `main.tf` example and is attached to an instance running a simple
web server. Please note that any service accounts operating the Vault Cluster are
NOT the same service account the client uses the authenticate. You can read more
about Vault Role creation and check which other parameters you can specify [here][create_role].

Because the Vault Cluster is also running on GCP, the credentials to do the
necessary verifications against the Google API are automatically available, but
they could also have been configured with `vault write auth/gcp/config credentials=@/path/to/credentials.json`.

```bash
vault auth enable gcp

vault policy write "example-policy" -<<EOF
path "secret/example_*" {
  capabilities = ["create", "read"]
}
EOF

vault write \
  auth/gcp/role/example_role_name \
  project_id="<project id>" \
  type="iam" \
  policies="example-policy" \
  bound_service_accounts="<client service account email>"
```

See the whole example script at [startup-script-vault.sh][startup_vault].


### Authenticating from an instance

The vault cli takes care of generating the JWT token, sending it with its login
request and storing the client token that is returned with a successful authentication.

```bash
vault login \
  -method=gcp \
  role="example_role_name" \
  jwt_exp="15m" \
  project="<project id>" \
  service_account="<client service account email>"

vault read secret/example_gruntwork
```

To see the full script for authenticating check the [client startup script][startup_client].


[auth_diagram]: https://raw.githubusercontent.com/hashicorp/terraform-google-vault/master/examples/vault-cluster-authentication-iam/images/iam_auth.svg
[generate_jwt]: https://www.vaultproject.io/docs/auth/gcp.html#generating-iam-jwt
[vault_cluster]: https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster
[private_vault]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private
[auth_methods]: https://www.vaultproject.io/docs/auth/index.html
[gcp_auth]: https://www.vaultproject.io/docs/auth/gcp.html
[iam_auth]: https://www.vaultproject.io/docs/auth/gcp.html#iam-login
[gce_example]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-authentication-gce
[google_image]: https://cloud.google.com/compute/docs/images
[image_example]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image
[dnsmasq_module]: https://github.com/hashicorp/terraform-aws-consul/tree/master/modules/install-dnsmasq
[dnsmasq]: http://www.thekelleys.org.uk/dnsmasq/doc.html
[jwt]: https://jwt.io/
[auto_unseal]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-enterprise
[policies_doc]: https://www.vaultproject.io/docs/concepts/policies.html
[create_role]: https://www.vaultproject.io/api/auth/gcp/index.html#create-role
[startup_vault]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-authentication-iam/startup-script-vault.sh
[startup_client]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-authentication-iam/startup-script-client.sh
