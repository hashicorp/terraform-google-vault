# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the Vault cluster (e.g. vault-stage). This variable is used to namespace all resources created by this module."
}

variable "cluster_tag_name" {
  description = "The tag name that the Vault Compute Instances use to automatically discover each other and form a cluster."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "api_port" {
  description = "The port used by clients to talk to the Vault Server API"
  default = 8200
}

variable "network_name" {
  description = "The URL of the VPC Network where all resources should be created. If left blank, we will use the default VPC network."
  default = ""
}

# Health Check options

variable "health_check_description" {
  description = "A description to add to the Health Check created by this module."
  default = ""
}

variable "health_check_path" {
  description = "The URL path the Health Check will query. Must return a 200 OK when the service is ready to receive requests from the Load Balancer."
  default     = "/v1/sys/health?standbyok=true"
}

variable "health_check_interval_sec" {
  description = "The number of seconds between each Health Check attempt."
  default = 15
}

variable "health_check_timeout_sec" {
  description = "The number of seconds to wait before the Health Check declares failure."
  default = 5
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive successes required to consider the Compute Instance healthy."
  default = 2
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive failures required to consider the Compute Instance unhealthy."
  default = 2
}

# Forwarding Rule Options

variable "forwarding_rule_description" {
  description = "The description added to the Forwarding Rule created by this module."
  default = ""
}

variable "forwarding_rule_ip_address" {
  description = "The static IP address to assign to the Forwarding Rule. If not set, an ephemeral IP address is used."
  default = ""
}

# Target Pool Options

variable "target_pool_description" {
  description = "The description added to the Target Pool created by this module."
  default = ""
}

variable "target_pool_session_affinity" {
  description = "How to distribute load across the Target Pool. Options are NONE (no affinity), CLIENT_IP (hash of the source/dest addresses/ports), and CLIENT_IP_PROTO also includes the protocol."
  default = "NONE"
}

# Firewall Rule Options

variable "firewall_rule_description" {
  description = "A description to add to the Firewall Rule created by this module."
  default = ""
}