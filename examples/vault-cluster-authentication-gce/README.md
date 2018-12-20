# Vault Cluster and Web Client with GCE Authentication Example

This example shows how to use the metadata from a [GCE Instance][gce_instance] to
authenticate to a [vault cluster][vault_cluster].

Vault provides multiple ways to authenticate a human or machine to Vault, known as
[auth methods][auth_methods]. For example, a human can authenticate with a Username
& Password or with GitHub.

Among those methods you will find [GCP][gcp_auth]. The way it works is that Vault
understands GCP as a trusted third party, and relies on GCP itself for affirming
if an authentication source is a legitimate source or not.

There are currently two ways a GCP resource can authenticatate to Vault: `gce` and `iam`.
In this example, we demonstrate the [GCP GCE Auth Method][gce_auth].

For more info on how the Vault cluster works, check out the [vault-cluster][vault_cluster]
documentation. For an example on using the `iam` method, check out the
[vault-authentication-iam example][iam_example].

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

## GCE Auth

GCE auth is a process in which Vault relies on information about a GCE instance
trying to assume a desired authentication role. For different resources that are
not GCE instances, please refer to the [`iam` auth method example][iam_example].

The workflow is that the client trying to authenticate itself will send a
[JSON Web Token (JWT)][jwt], a JSON-based open standard for creating access tokens,
in its login request, Vault verifies the JWT with GCP as a proof-of-identity,
checks against a predefined Vault authentication role, then returns a client
token that the client can use for making future requests to Vault.

![auth diagram][auth_diagram]

In this example, the JWT can be obtained from the GCE Intance's own metadata endpoint.

It is important to notice that, to perform the authentication, certain scopes are
necessary when configuring the service account for the resources. For the GCE
method, both the authenticating instance's and the vault cluster's instance
template need to have the `cloud-platform` scope.

### Configuring the Vault server

Before we try to authenticate, we must be sure that the Vault Server is configured
properly and prepared to receive requests. First, we must make sure the Vault server
has been initialized (using `vault operator init`) and unsealed (either using
`vault operator unseal` or the [auto-unsealing feature][auto_unseal]).
Next, we must enable Vault to support the GCP auth method (using `vault auth enable gcp`).
Finally, we must define the correct Vault Policies and Roles to declare who will
have access to which resources in Vault.

[Policies][policies_doc] are rules that grant or forbid access and actions to certain paths in
Vault. With one or more policies on hand, you can then finally create the authentication role.

When you create a Role in Vault, you define the Policies that are attached to that
Role, how principals who assume that Role will authenticate and other parameters
related to the authentication of that role such as when does the token issued by
a successful attempt will expire. When your Role uses the GCE GCP Auth method,
you also specify which of the GCE properties will be required by the principal
(in this case, the GCE Instance) in order to successfully authenticate.

In our example we create a simple Vault Policy that allows writing and reading from
secrets in the path `secret` namespaced with the prefix `example_`, and then create
a Vault Role that allows authentication from all instances in a specific Zone and
with certain labels. You can read more about Role creation and check which other
instance metadata you can use on auth [here][create_role].


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
  type="gce" \
  policies="example-policy" \
  bound_zones="asia-east1-a" \
  bound_labels="example_label:example_value,another_label:another_value"
```

See the whole example script at [startup-script-vault.sh][startup_vault].


### Authenticating from an instance

The token used to authenticate to Vault is a [JSON Web Token (JWT)][jwt] that can
be fetched on the GCE's instance metadata endpoint and will be part of the body of
data sent with the login request.

```bash
JWT_TOKEN=$(curl \
  --fail \
  --header "Metadata-Flavor: Google" \
  --get \
  --data-urlencode "audience=vault/<role name>}" \
  --data-urlencode "format=full" \
  "http://metadata/computeMetadata/v1/instance/service-accounts/<service account email>/identity")

LOGIN_PAYLOAD=$(cat <<EOF
{
  "role":"${example_role_name}",
  "jwt":"$JWT_TOKEN"
}
EOF
)
curl --fail --request POST --data '$LOGIN_PAYLOAD' https://vault.service.consul:8200/v1/auth/gcp/login
```

After sending the login request to Vault, Vault will verify it against GCP and
return a JSON object with your login information. This JSON contains the `client_token`,
that you will send with your future operations requests to Vault.

Please note, that this could also have been achieved using the Vault cli tool
instead of using `curl`. To see the full script for authenticating check the
[client startup script][startup_client].

[auth_diagram]: https://www.vaultproject.io/img/vault-gcp-gce-auth-workflow.svg
[gce_instance]: https://cloud.google.com/compute/docs/instances/
[vault_cluster]: https://github.com/hashicorp/terraform-google-vault/tree/master/modules/vault-cluster
[private_vault]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-private
[auth_methods]: https://www.vaultproject.io/docs/auth/index.html
[gcp_auth]: https://www.vaultproject.io/docs/auth/gcp.html
[gce_auth]: https://www.vaultproject.io/docs/auth/gcp.html#gce-login
[iam_example]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-authentication-iam
[google_image]: https://cloud.google.com/compute/docs/images
[image_example]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-consul-image
[dnsmasq_module]: https://github.com/hashicorp/terraform-aws-consul/tree/master/modules/install-dnsmasq
[dnsmasq]: http://www.thekelleys.org.uk/dnsmasq/doc.html
[jwt]: https://jwt.io/
[auto_unseal]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-enterprise
[policies_doc]: https://www.vaultproject.io/docs/concepts/policies.html
[create_role]: https://www.vaultproject.io/api/auth/gcp/index.html#create-role
[startup_vault]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-authentication-gce/startup-script-vault.sh
[startup_client]: https://github.com/hashicorp/terraform-google-vault/tree/master/examples/vault-cluster-authentication-gce/startup-script-client.sh
