#!/bin/bash
# This script is meant to be run as the Startup Script of each Compute Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in server mode. This script assumes it's running in a Compute Instance
# based on a Google Image built from the Packer template in https://github.com/hashicorp/terraform-google-consul at
# /examples/consul-image.

set -e

# Send the log output from this script to startup-script.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/startup-script.log|logger -t startup-script -s 2>/dev/console) 2>&1

# Note that any variables below with <dollar-sign><curly-brace><var-name><curly-brace> are expected to be interpolated by Terraform.
/opt/consul/bin/run-consul --server --cluster-tag-name "${cluster_tag_name}"
