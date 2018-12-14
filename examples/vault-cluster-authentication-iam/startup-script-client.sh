#!/bin/bash
# This script is meant to be run as the Startup Script of a Compute Instance
# while it's booting. The script uses the run-consul script to configure and start
# Consul in client mode, and the Vault cli tool, to perform certain operations, such
# as login and reading a secret from a Vault Cluster. This script also serves
# a simple webserver with a message read from Vault, for test purposes, so we
# can curl the response and check that the authentication is working.
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

# Consul is being used as a service discovery mechanism, thanks to dnsmasq, so
# this web client can locate the vault cluster through the following
# private hostname: vault.service.consul
# We can use the vault cli to reach the Google API to sign a JSON Web Token and
# perform the authentication with a bound Service Account.
# The Vault Role must be previously created and configured by a vault server
LOGIN_OUTPUT=$(retry \
   "vault login -method=gcp -address='https://vault.service.consul:8200' role='${example_role_name}' jwt_exp=15m project='${project_id}' service_account='${service_account_email}'" \
   "Attempting to login to Vault")

# After logging in, we can use the vault cli to make operations such as reading a secret
RESPONSE_READ=$(retry \
  "vault read -address=https://vault.service.consul:8200 secret/example_gruntwork" \
  "Trying to read secret from vault")

# Serves the answer in a web server so we can test that this auth client is
# authenticating to vault and fetching data correctly
echo $RESPONSE_READ | awk '{print $NF}' > index.html
python -m SimpleHTTPServer 8080 &
