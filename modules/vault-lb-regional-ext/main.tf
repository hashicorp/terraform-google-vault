# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.10.3 AND ABOVE
# Why? Because we want the latest GCP updates available in https://github.com/terraform-providers/terraform-provider-google
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.10.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LOAD BALANCER (FORWARDING RULE)
# The Google Cloud API for creating a Load Balancer is somehwat confusing. By creating a Forwarding Rule, we will
# automatically create an external (public-facing) Load Balancer specific to a Region.
# ---------------------------------------------------------------------------------------------------------------------

# A Forwarding Rule receives inbound requests and forwards them to the specified Target Pool
resource "google_compute_forwarding_rule" "vault" {
  name = "${var.cluster_name}-fr"
  description = "${var.forwarding_rule_description}"
  ip_address = "${var.forwarding_rule_ip_address}"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  network = "${var.network_name}"
  port_range = "${var.http_api_port}"
  target = "${google_compute_target_pool.vault.self_link}"
}

# The Load Balancer (Forwarding rule) will only forward requests to Compute Instances in the associated Target Pool.
# Note that this Target Pool is populated by modifying the Instance Group (var.compute_instance_group_name) to add its
# member Instances to this Target Pool.
resource "google_compute_target_pool" "vault" {
  name = "${var.cluster_name}-tp"
  description = "${var.target_pool_description}"
  session_affinity = "${var.target_pool_session_affinity}"
  health_checks = ["${google_compute_http_health_check.vault.name}"]
}

# Add a Health Check so that the Load Balancer will only route to healthy Compute Instances. Note that this Health
# Check has no effect on whether GCE will attempt to reboot the Compute Instance. Note also that the Google API will
# only allow a Target Pool to reference an HTTP Health Check. HTTPS or TCP Health Checks are not yet supported.
resource "google_compute_http_health_check" "vault" {
  name = "${var.cluster_name}-hc"
  description = "${var.health_check_description}"
  check_interval_sec = "${var.health_check_interval_sec}"
  timeout_sec = "${var.health_check_timeout_sec}"
  healthy_threshold = "${var.health_check_healthy_threshold}"
  unhealthy_threshold = "${var.health_check_unhealthy_threshold}"

  port = "${var.http_api_port}"
  request_path = "${var.health_check_request_path}"
}

# The Load Balancer may need explicit permission to forward traffic to our Vault Cluster.
resource "google_compute_firewall" "load_balancer" {
  name    = "${var.cluster_name}-rule-lb"
  description = "${var.firewall_rule_description}"
  network = "${var.network_name == "" ? "default" : var.network_name}"

  allow {
    protocol = "tcp"
    ports    = ["${var.http_api_port}"]
  }

  # These hardcoded IP addresses represent the Load Balancer and Health Checker, per Google Cloud Docs (https://goo.gl/xULu8U)
  # TODO: Remove 0.0.0.0/0 once I understand why the Load Balancer fails without this rule.
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "0.0.0.0/0"]
  target_tags = ["${var.cluster_tag_name}"]
}