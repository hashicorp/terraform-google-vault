#!/bin/bash
# This script is meant to be run as the Startup Script of each Compute Instance while it's booting. The script uses the
# run-consul and run-vault scripts to configure and start both Vault and Consul in client mode. This script assumes it's
# running in a Compute Instance based on a Google Image built from the Packer template in
# examples/vault-consul-image/vault-consul.json.

set -e

# Send the log output from this script to startup-script.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

# The Packer template puts the TLS certs in these file paths
readonly VAULT_TLS_CERT_FILE="/opt/vault/tls/vault.crt.pem"
readonly VAULT_TLS_KEY_FILE="/opt/vault/tls/vault.key.pem"

# Note that any variables below with <dollar-sign><curly-brace><var-name><curly-brace> are expected to be interpolated by Terraform.
/opt/consul/bin/run-consul --client --cluster-tag-name "${consul_cluster_tag_name}"
/opt/vault/bin/run-vault --gcs-bucket ${vault_cluster_tag_name} \
  --tls-cert-file "$VAULT_TLS_CERT_FILE" \
  --tls-key-file "$VAULT_TLS_KEY_FILE" \
  --enable-auto-unseal \
  --auto-unseal-project "${vault_auto_unseal_project_id}" \
  --auto-unseal-region "${vault_auto_unseal_region}" \
  --auto-unseal-key-ring "${vault_auto_unseal_key_ring}" \
  --auto-unseal-crypto-key "${vault_auto_unseal_crypto_key}"

# We run an nginx server to expose an HTTP endpoint that will be used solely for Vault health checks. This is because
# Google Cloud only permits HTTP health checks to be associated with the Load Balancer.
/opt/nginx/bin/run-nginx --port ${web_proxy_port} --proxy-pass-url "https://127.0.0.1:8200/v1/sys/health?standbyok=true"

# Initializes a vault server
# run-vault is running on the background and we have to wait for it to be done,
# so in case this fails we retry.
function retry_init {
  for i in $(seq 1 20); do
    echo "Initializing Vault agent..."
    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    server_output=$(/opt/vault/bin/vault operator init) && exit_status=0 || exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
      return
    fi
    echo "Failed to auth initialize Vault. Will sleep for 5 seconds and try again."
    sleep 5
  done

  echo "Failed to initialize Vault."
  exit $exit_status
}

retry_init

# TODO - add license key to vault

# Normally we would unseal Vault here with the generated keys, however we rely on the Auto Unseal
# feature (https://www.vaultproject.io/docs/enterprise/auto-unseal/index.html) to do that for us automatically.
/usr/bin/supervisorctl restart vault

# Writes some secret, this secret is being written by terraform for test purposes
# Please note that normally we would never pass a secret this way
# This is just so we can verify that our example instance is authenticating correctly
/opt/vault/bin/vault write secret/example_gruntwork the_answer=${example_secret}
