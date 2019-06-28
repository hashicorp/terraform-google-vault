# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the Vault cluster (e.g. vault-stage). This variable is used to namespace all resources created by this module."
  type        = string
}

variable "cluster_tag_name" {
  description = "The tag name that the Vault Compute Instances use to automatically discover each other and form a cluster."
  type        = string
}

variable "health_check_path" {
  description = "The URL path the Health Check will query. Must return a 200 OK when the service is ready to receive requests from the Load Balancer."
  type        = string
}

variable "health_check_port" {
  description = "The port to be used by the Health Check."
  type        = number
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "api_port" {
  description = "The port used by clients to talk to the Vault Server API"
  type        = number
  default     = 8200
}

variable "network_name" {
  description = "The URL of the VPC Network where all resources should be created. If left blank, we will use the default VPC network."
  type        = string
  default     = null
}

# Health Check options

variable "health_check_description" {
  description = "A description to add to the Health Check created by this module."
  type        = string
  default     = null
}

variable "health_check_interval_sec" {
  description = "The number of seconds between each Health Check attempt."
  type        = number
  default     = 15
}

variable "health_check_timeout_sec" {
  description = "The number of seconds to wait before the Health Check declares failure."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive successes required to consider the Compute Instance healthy."
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive failures required to consider the Compute Instance unhealthy."
  type        = number
  default     = 2
}

# Forwarding Rule Options

variable "forwarding_rule_description" {
  description = "The description added to the Forwarding Rule created by this module."
  type        = string
  default     = null
}

variable "forwarding_rule_ip_address" {
  description = "The static IP address to assign to the Forwarding Rule. If not set, an ephemeral IP address is used."
  type        = string
  default     = null
}

# Target Pool Options

variable "target_pool_description" {
  description = "The description added to the Target Pool created by this module."
  type        = string
  default     = null
}

variable "target_pool_session_affinity" {
  description = "How to distribute load across the Target Pool. Options are NONE (no affinity), CLIENT_IP (hash of the source/dest addresses/ports), and CLIENT_IP_PROTO also includes the protocol."
  type        = string
  default     = "NONE"
}

# Firewall Rule Options

variable "firewall_rule_description" {
  description = "A description to add to the Firewall Rule created by this module."
  type        = string
  default     = null
}

variable "allow_access_from_cidr_blocks" {
  description = "The list of CIDR-formatted IP address ranges from which access to the Vault load balancer will be allowed."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
