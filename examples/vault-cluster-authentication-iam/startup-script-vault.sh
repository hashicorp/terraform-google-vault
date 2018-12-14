#!/bin/bash
# This script is meant to be run as the Startup Script of each Compute Instance
# while it's booting. The script uses the run-consul and run-vault scripts to
# configure and start Consul in client mode and Vault in server mode, and then,
# after initializing and unsealing vault, it configures vault authentication and
# writes an example that can be read by a client. This script assumes it's running
# in a Compute Instance based on a Google Image built from the Packer template in
# examples/vault-consul-image/vault-consul.json.
#
# For more information about GCP auth, please refer to https://www.vaultproject.io/docs/auth/gcp.html
# ==========================================================================

set -e

# Send the log output from this script to startup-script.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

# The Packer template puts the TLS certs in these file paths
readonly VAULT_TLS_CERT_FILE="/opt/vault/tls/vault.crt.pem"
readonly VAULT_TLS_KEY_FILE="/opt/vault/tls/vault.key.pem"

# Note that any variables below with <dollar-sign><curly-brace><var-name><curly-brace> are expected to be interpolated by Terraform.
/opt/consul/bin/run-consul --client --cluster-tag-name "${consul_cluster_tag_name}"
/opt/vault/bin/run-vault --gcs-bucket ${vault_cluster_tag_name} --tls-cert-file "$VAULT_TLS_CERT_FILE" --tls-key-file "$VAULT_TLS_KEY_FILE" ${enable_vault_ui}

# Log the given message. All logs are written to stderr with a timestamp.
function log {
 local -r message="$1"
 local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
 >&2 echo -e "$timestamp $message"
}

# A retry function that attempts to run a command a number of times and returns the output
function retry {
  local -r cmd="$1"
  local -r description="$2"

  for i in $(seq 1 30); do
    log "$description"

    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    output=$(eval "$cmd") && exit_status=0 || exit_status=$?
    log "$output"
    if [[ $exit_status -eq 0 ]]; then
      echo "$output"
      return
    fi
    log "$description failed. Will sleep for 10 seconds and try again."
    sleep 10
  done;

  log "$description failed after 30 attempts."
  exit $exit_status
}

# Initializes a vault server
# run-vault is running on the background and we have to wait for it to be done,
# so in case this fails we retry.
SERVER_OUTPUT=$(retry \
  "/opt/vault/bin/vault operator init" \
  "Trying to initialize vault")

# The expected output should be similar to this:
# ==========================================================================
# Unseal Key 1: ddPRelXzh9BdgqIDqQO9K0ldtHIBmY9AqsTohM6zCRl7
# Unseal Key 2: liSgypzdVrAxz73KbKyCMjVeSnRMuxCZMk1PWIZdjENS
# Unseal Key 3: pmgeVu/fs8+jl8bOzf3Cq56BFufm4o7Sxt2oaUcvt6Dp
# Unseal Key 4: i3W2xJEyUqUqcO1QSjTA+Ua0RUPxnNWM27AqaC8wW7Zh
# Unseal Key 5: vHsQtCRgfblPeFYw1hhCVbji0MoNUP8zyIWhLWs3PebS
#
# Initial Root Token: cb076fc1-cc1f-6766-795f-b3822ba1ac57
#
# Vault initialized with 5 key shares and a key threshold of 3. Please securely
# distribute the key shares printed above. When the Vault is re-sealed,
# restarted, or stopped, you must supply at least 3 of these keys to unseal it
# before it can start servicing requests.
#
# Vault does not store the generated master key. Without at least 3 key to
# reconstruct the master key, Vault will remain permanently sealed!
#
# It is possible to generate new unseal keys, provided you have a quorum of
# existing unseal keys shares. See "vault operator rekey" for more information.
# ==========================================================================

# Unseals the server with 3 keys from this output
# Please note that this is not how it should be done in production as it is not
# secure and and we are not storing any of the tokens, so in case it gets resealed,
# the tokens are lost and we wouldn't be able to unseal it again. Normally, an
# operator would SSH and unseal the server in each node manually or, ideally, it
# should be auto unsealed https://www.vaultproject.io/docs/enterprise/auto-unseal/index.html
# For this quick example specifically, we are just running one vault server and
# unsealing it like this for simplicity as this example focuses on authentication
# and not on unsealing. For a more detailed example on auto unsealing, check the
# vault enterprise example at /examples/vault-cluster-enterprise
FIRST_THREE_LINES=$(echo "$SERVER_OUTPUT" | head -n 3)
UNSEAL_KEYS=$(echo "$FIRST_THREE_LINES" | awk '{ print $4; }')
echo "$UNSEAL_KEYS" | xargs -l /opt/vault/bin/vault operator unseal

# Exports the client token environment variable necessary for running the following vault commands
SEVENTH_LINE=$(echo "$SERVER_OUTPUT" | head -n 7 | tail -n 1)
export VAULT_TOKEN=$(echo "$SEVENTH_LINE" | awk '{ print $4; }')


# ==========================================================================
# BEGIN GCP IAM AUTH EXAMPLE
# ==========================================================================
# Auth methods must be configured in advance before users or machines can authenticate.

# Enables authentication
# This is an http request, and sometimes fails, hence we retry
retry \
  "/opt/vault/bin/vault auth enable gcp" \
  "Trying to enable gcp authentication"

# To be able to verify authentication attempts with the help of the Google API,
# Vault needs to have access to a service account with the necessary roles.
# In this example runs on a Google Compute Instance, which means that the credentials
# are provided to Vault automatically. but the following command would be necessary
# for using the GCP auth method outside of GCP, such as locally, for example.
#
# vault write auth/gcp/config credentials=@/path/to/credentials.json

# Creates a policy that allows writing and reading from an "example_" prefix at "secret" backend
/opt/vault/bin/vault policy write "example-policy" -<<EOF
path "secret/example_*" {
  capabilities = ["create", "read"]
}
EOF

# Creates an authentication role
# The Vault Role name, Project ID and GCP service account email are being passed by terraform
# This example will allow GCP resources using a given service account to authenticate
# Read more at: https://www.vaultproject.io/docs/auth/gcp.html#iam-login
/opt/vault/bin/vault write \
  auth/gcp/role/${example_role_name}\
  project_id="${project_id}" \
  type="iam" \
  policies="example-policy" \
  bound_service_accounts="${client_service_account_email}"

# ==========================================================================
# END GCP IAM AUTH EXAMPLE
# ==========================================================================

# Writes some secret, this secret is being written by terraform for test purposes
# Please note that normally we would never pass a secret this way as it is not secure
# This is just so we can have a test verifying that our web client instance is
# authenticating correctly
/opt/vault/bin/vault write secret/example_gruntwork the_answer=${example_secret}
