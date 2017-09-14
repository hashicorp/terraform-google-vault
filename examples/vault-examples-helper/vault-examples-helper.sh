#!/bin/bash
# A script that is meant to be used with the root Vault cluster example to:
#
# 1. Wait for the Vault server cluster to come up.
# 2. Print out the names of the Vault servers.
# 3. Print out some example commands you can run against your Vault servers.

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

readonly MAX_RETRIES=30
readonly SLEEP_BETWEEN_RETRIES_SEC=10

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_is_installed {
  local readonly name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function get_optional_terraform_output {
  local readonly output_name="$1"
  terraform output -no-color "$output_name"
}

function get_required_terraform_output {
  local readonly output_name="$1"
  local output_value

  output_value=$(get_optional_terraform_output "$output_name")

  if [[ -z "$output_value" ]]; then
    log_error "Unable to find a value for Terraform output $output_name"
    exit 1
  fi

  echo "$output_value"
}

#
# Usage: join SEPARATOR ARRAY
#
# Joins the elements of ARRAY with the SEPARATOR character between them.
#
# Examples:
#
# join ", " ("A" "B" "C")
#   Returns: "A, B, C"
#
function join {
  local readonly separator="$1"
  shift
  local readonly values=("$@")

  printf "%s$separator" "${values[@]}" | sed "s/$separator$//"
}

function get_all_vault_server_property_values {
  local server_property_name="$1"

  local gcp_project
  local gcp_zone
  local cluster_tag_name
  local expected_num_vault_servers

  gcp_project=$(get_required_terraform_output "gcp_project")
  gcp_zone=$(get_required_terraform_output "gcp_zone")
  cluster_tag_name=$(get_required_terraform_output "cluster_tag_name")
  expected_num_vault_servers=$(get_required_terraform_output "vault_cluster_size")

  log_info "Looking up $server_property_name for $expected_num_vault_servers Vault server Compute Instances."

  local vals
  local i

  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    vals=($(get_vault_server_property_values "$gcp_project" "$gcp_zone" "$cluster_tag_name" "$server_property_name"))
    if [[ "${#vals[@]}" -eq "$expected_num_vault_servers" ]]; then
      log_info "Found $server_property_name for all $expected_num_vault_servers expected Vault servers!"
      echo "${vals[@]}"
      return
    else
      log_warn "Found $server_property_name for ${#vals[@]} of $expected_num_vault_servers Vault servers. Will sleep for $SLEEP_BETWEEN_RETRIES_SEC seconds and try again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Failed to find the $server_property_name for $expected_num_vault_servers Vault server Compute Instances after $MAX_RETRIES retries."
  exit 1
}

function wait_for_all_vault_servers_to_come_up {
  local readonly server_ips=($@)

  local expected_num_vault_servers
  expected_num_vault_servers=$(get_required_terraform_output "vault_cluster_size")

  log_info "Waiting for $expected_num_vault_servers Vault servers to come up"

  local server_ip
  for server_ip in "${server_ips[@]}"; do
    wait_for_vault_server_to_come_up "$server_ip"
  done
}

function wait_for_vault_server_to_come_up {
  local readonly server_ip="$1"

  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    local readonly vault_health_url="https://$server_ip:8200/v1/sys/health"
    log_info "Checking health of Vault server via URL $vault_health_url"

    local response
    local status
    local body

    response=$(curl --show-error --location --insecure --silent --write-out "HTTPSTATUS:%{http_code}" "$vault_health_url" || true)
    status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')

    log_info "Got a $status response from Vault server $server_ip with body:\n$body"

    # Response code for the health check endpoint are defined here: https://www.vaultproject.io/api/system/health.html

    if [[ "$status" -eq 200 ]]; then
      log_info "Vault server $server_ip is initialized, unsealed, and active."
      return
    elif [[ "$status" -eq 429 ]]; then
      log_info "Vault server $server_ip is unsealed and in standby mode."
      return
    elif [[ "$status" -eq 501 ]]; then
      log_info "Vault server $server_ip is uninitialized."
      return
    elif [[ "$status" -eq 503 ]]; then
      log_info "Vault server $server_ip is sealed."
      return
    else
      log_info "Vault server $server_ip returned unexpected status code $status. Will sleep for $SLEEP_BETWEEN_RETRIES_SEC seconds and check again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Did not get a successful response code from Vault server $server_ip after $MAX_RETRIES retries."
  exit 1
}

function get_vault_server_property_values {
  local readonly gcp_project="$1"
  local readonly gcp_zone="$2"
  local readonly cluster_tag_name="$3"
  local readonly property_name="$4"
  local instances

  cluster_tag_name=$(get_required_terraform_output "cluster_tag_name")

  log_info "Fetching external IP addresses for Vault Server Compute Instances with tag \"$cluster_tag_name\""

  instances=$(gcloud compute instances list \
    --project "$gcp_project"\
    --filter "zone : $gcp_zone" \
    --filter "tags.items~^$cluster_tag_name\$" \
    --format "value($property_name)")

  echo "$instances"
}

function get_all_vault_server_ips {
  get_all_vault_server_property_values "EXTERNAL_IP"
}

function get_all_vault_server_names {
  get_all_vault_server_property_values "NAME"
}

function print_instructions {
  local readonly project="$1"
  local readonly zone="$2"
  shift; shift;
  local readonly server_names=($@)
  local server_name="${server_names[0]}"

  local instructions=()
  instructions+=("\nThe following Vault servers are running:\n\n${server_names[@]/#/    }\n")

  instructions+=("To initialize your Vault cluster, SSH to one of the servers and run the init command:\n")
  instructions+=("    gcloud compute --project \"$project\" ssh --zone \"$zone\" $server_name")
  instructions+=("    vault init")

  instructions+=("\nTo unseal your Vault cluster, SSH to each of the servers and run the unseal command with 3 of the 5 unseal keys:\n")
  for server_name in "${server_names[@]}"; do
    instructions+=("    gcloud compute --project \"$project\" ssh --zone \"$zone\" $server_name")
    instructions+=("    vault unseal (run this 3 times)\n")
  done

  instructions+=("\nOnce your cluster is unsealed, you can read and write secrets by SSHing to any of the servers:\n")
  instructions+=("    gcloud compute --project \"$project\" ssh --zone \"$zone\" $server_name")
  instructions+=("    vault auth")
  instructions+=("    vault write secret/example value=secret")
  instructions+=("    vault read secret/example")

  local instructions_str
  instructions_str=$(join "\n" "${instructions[@]}")

  echo -e "$instructions_str\n"
}

function run {
  assert_is_installed "gcloud"
  assert_is_installed "jq"
  assert_is_installed "terraform"
  assert_is_installed "curl"

  local gcp_project
  local gcp_zone
  local server_ips
  local server_names

  gcp_project=$(get_required_terraform_output "gcp_project")
  gcp_zone=$(get_required_terraform_output "gcp_zone")
  server_ips=$(get_all_vault_server_ips)
  server_names=$(get_all_vault_server_names)

  wait_for_all_vault_servers_to_come_up "$server_ips"

  print_instructions "$gcp_project" "$gcp_zone" "$server_names"
}

run