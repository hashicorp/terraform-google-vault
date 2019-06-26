output "forwarding_rule_id" {
  value = google_compute_forwarding_rule.vault.id
}

output "forwarding_rule_url" {
  value = google_compute_forwarding_rule.vault.self_link
}

output "target_pool_id" {
  value = google_compute_target_pool.vault.id
}

output "target_pool_url" {
  value = google_compute_target_pool.vault.self_link
}

output "health_check_id" {
  value = google_compute_http_health_check.vault.id
}

output "health_check_url" {
  value = google_compute_http_health_check.vault.self_link
}

output "firewall_rule_id" {
  value = google_compute_firewall.load_balancer.id
}

output "firewall_rule_url" {
  value = google_compute_firewall.load_balancer.self_link
}

