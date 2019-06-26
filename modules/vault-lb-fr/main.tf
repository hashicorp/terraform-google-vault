# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.12.0 AND ABOVE
# This module has been updated with 0.12 syntax, which means the example is no longer
# compatible with any versions below 0.12.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LOAD BALANCER FORWARDING RULE
# In GCP, Google has already created the load balancer itself so there is no new load balancer resource to create. However,
# to leverage this load balancer, we must create a Forwarding Rule specially for our Compute Instances. By creating a
# Forwarding Rule, we automatically create an external (public-facing) Load Balancer in the GCP console.
# ---------------------------------------------------------------------------------------------------------------------

# A Forwarding Rule receives inbound requests and forwards them to the specified Target Pool
resource "google_compute_forwarding_rule" "vault" {
  name                  = "${var.cluster_name}-fr"
  description           = var.forwarding_rule_description
  ip_address            = var.forwarding_rule_ip_address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  network               = var.network_name
  port_range            = var.api_port
  target                = google_compute_target_pool.vault.self_link
}

# The Load Balancer (Forwarding rule) will only forward requests to Compute Instances in the associated Target Pool.
# Note that this Target Pool is populated by modifying the Instance Group containing the Vault nodes to add its member
# Instances to this Target Pool.
resource "google_compute_target_pool" "vault" {
  name             = "${var.cluster_name}-tp"
  description      = var.target_pool_description
  session_affinity = var.target_pool_session_affinity
  health_checks    = [google_compute_http_health_check.vault.name]
}

# Add a Health Check so that the Load Balancer will only route to healthy Compute Instances. Note that this Health
# Check has no effect on whether GCE will attempt to reboot the Compute Instance. Note also that the Google API will
# only allow a Target Pool to reference an HTTP Health Check. HTTPS or TCP Health Checks are not yet supported.
resource "google_compute_http_health_check" "vault" {
  name                = "${var.cluster_name}-hc"
  description         = var.health_check_description
  check_interval_sec  = var.health_check_interval_sec
  timeout_sec         = var.health_check_timeout_sec
  healthy_threshold   = var.health_check_healthy_threshold
  unhealthy_threshold = var.health_check_unhealthy_threshold

  port         = var.health_check_port
  request_path = var.health_check_path
}

# The Load Balancer may need explicit permission to forward traffic to our Vault Cluster.
resource "google_compute_firewall" "load_balancer" {
  name        = "${var.cluster_name}-rule-lb"
  description = var.firewall_rule_description
  network     = var.network_name == null ? "default" : var.network_name

  allow {
    protocol = "tcp"
    ports    = [var.api_port]
  }

  # "130.211.0.0/22" - Enable inbound traffic from the Google Cloud Load Balancer (https://goo.gl/xULu8U)
  # "35.191.0.0/16" - Enable inbound traffic from the Google Cloud Health Checkers (https://goo.gl/xULu8U)
  # "0.0.0.0/0" - Enable any IP address to reach our nodes
  source_ranges = concat(
    ["130.211.0.0/22", "35.191.0.0/16"],
    var.allow_access_from_cidr_blocks,
  )

  target_tags = [var.cluster_tag_name]
}
