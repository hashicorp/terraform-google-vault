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
# Note: This script will run on all nodes so one node will initialize Vault and become the leader and the rest will fail.
function retry_init {
  for i in $(seq 1 20); do
    echo "Initializing Vault..."
    # The boolean operations with the exit status are there to temporarily circumvent the "set -e" at the
    # beginning of this script which exits the script immediatelly for error status while not losing the exit status code
    server_output=$(/opt/vault/bin/vault operator init) && exit_status=0 || exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
      return
    fi
    echo "Failed to initialize Vault. Will sleep for 5 seconds and try again."
    sleep 5
  done

  echo "Failed to initialize Vault."
  exit $exit_status
}

retry_init

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
# Please note that this is not how it should be done in production as it is not secure and and we are
# not storing any of the tokens.
echo "$server_output" | head -n 3 | awk '{ print $4; }' | xargs -l /opt/vault/bin/vault operator unseal

# Exports the client token environment variable necessary for running the following vault commands
export VAULT_TOKEN=$(echo "$server_output" | head -n 7 | tail -n 1 | awk '{ print $4; }')

# Add the Enterprise license key to vault.
/opt/vault/bin/vault write /sys/license "text=${vault_enterprise_license_key}"

# Writes some secret, this secret is being written by Terraform for test purposes
# Please note that normally we would never pass a secret this way
# This is just so we can verify that our example instance is authenticating correctly
/opt/vault/bin/vault write secret/example_gruntwork the_answer=${example_secret}
