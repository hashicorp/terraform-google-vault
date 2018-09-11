output "cluster_tag_name" {
  value = "${var.cluster_name}"
}

output "instance_group_id" {
  value = "${google_compute_region_instance_group_manager.vault.id}"
}

output "instance_group_url" {
  value = "${google_compute_region_instance_group_manager.vault.self_link}"
}

output "instance_template_url" {
  value = "${data.template_file.compute_instance_template_self_link.rendered}"
}

output "firewall_rule_allow_intracluster_vault_url" {
  value = "${google_compute_firewall.allow_intracluster_vault.self_link}"
}

output "firewall_rule_allow_intracluster_vault_id" {
  value = "${google_compute_firewall.allow_intracluster_vault.id}"
}

output "firewall_rule_allow_inbound_api_url" {
  value = "${google_compute_firewall.allow_inbound_api.*.self_link}"
}

output "firewall_rule_allow_inbound_api_id" {
  value = "${google_compute_firewall.allow_inbound_api.*.id}"
}

output "firewall_rule_allow_inbound_health_check_url" {
  value = "${element(concat(google_compute_firewall.allow_inbound_health_check.*.self_link, list("")), 0)}"
}

output "firewall_rule_allow_inbound_health_check_id" {
  value = "${element(concat(google_compute_firewall.allow_inbound_health_check.*.id, list("")), 0)}"
}

output "bucket_name_url" {
  value = "${google_storage_bucket.vault_storage_backend.self_link}"
}

output "bucket_name_id" {
  value = "${google_storage_bucket.vault_storage_backend.id}"
}
