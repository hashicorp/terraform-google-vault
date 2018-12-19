#!/bin/bash
# This script is meant to be run as the Startup Script of a Compute Instance
# while it's booting. Afterwards it performs the necessary api requests to login
# to a Vault cluster. At the end it also serves a simple webserver with a message
# read from Vault, for test purposes, so we can curl the response and test that
# the authentication example is working as expected.
#
# This script assumes it's running in a Compute Instance based on a Google Image
# built from the Packer template in examples/vault-consul-image/vault-consul.json.
#
# For more information about GCP auth, please refer to https://www.vaultproject.io/docs/auth/gcp.html
# ==========================================================================

set -e

# Send the log output from this script to startup-script.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

# Note that any variables below with <dollar-sign><curly-brace><var-name><curly-brace> are expected to be interpolated by Terraform.
/opt/consul/bin/run-consul --client --cluster-tag-name "${consul_cluster_tag_name}"


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

# ==========================================================================
# BEGIN GCP GCE AUTH EXAMPLE
# ==========================================================================
# Getting the signed JWT token from instance metadata
# ==========================================================================
# `example_role_name is being filled by terraform, it should be the same name
# used to create the Vault Role when configuring the authentication on the Vault
# server. In this example we are using the default project service account, to
# fetch the necessary credentials. If you wish to use a different service account,
# then the service account email should be used instead of "default".
SERVICE_ACCOUNT="default"
JWT_TOKEN=$(curl \
  --fail \
  --header "Metadata-Flavor: Google" \
  --get \
  --data-urlencode "audience=vault/${example_role_name}" \
  --data-urlencode "format=full" \
  "http://metadata/computeMetadata/v1/instance/service-accounts/$SERVICE_ACCOUNT/identity")

# ==========================================================================
# Login
# ==========================================================================
# In this example, we are using the HTTP API to login and read secrets from vault,
# although the vault cli tool could also have been used. The vault cli tool makes
# this process easier by fetching the signed JWT token, needed for login, automatically.
# We have used the vault cli tool in the example with the IAM auth method, which
# you can find at /examples/vault-cluster-authentication-iam
# For more information on GCP auth, check https://www.vaultproject.io/docs/auth/gcp.html#authentication
LOGIN_PAYLOAD=$(cat <<EOF
{
  "role":"${example_role_name}",
  "jwt":"$JWT_TOKEN"
}
EOF
)

# Consul is being used as a service discovery mechanism, thanks to dnsmasq, so
# this server can locate the vault cluster through the following private
# hostname: vault.service.consul
LOGIN_OUTPUT=$(retry \
  "curl --fail --request POST --data '$LOGIN_PAYLOAD' https://vault.service.consul:8200/v1/auth/gcp/login" \
  "Attempting to login to vault")

# The login output contains the client token, which we will need to perform further
# operations on vault, such as reading a secret.
CLIENT_TOKEN=$(echo $LOGIN_OUTPUT | jq -r .auth.client_token)

# ==========================================================================
# Reading a secret
# ==========================================================================
RESPONSE_READ=$(retry \
  "curl --fail -H 'X-Vault-Token: $CLIENT_TOKEN' -X GET https://vault.service.consul:8200/v1/secret/example_gruntwork" \
  "Trying to read secret from vault")

# ==========================================================================
# END GCP GCE AUTH EXAMPLE
# ==========================================================================

# Serves the answer in a web server so we can test that this auth client is
# authenticating to vault and fetching data correctly
echo $RESPONSE_READ | jq -r .data.the_answer > index.html
python -m SimpleHTTPServer 8080 &
