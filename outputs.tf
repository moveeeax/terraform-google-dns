output "id" {
  description = "Identifier of the managed zone."
  value       = google_dns_managed_zone.this.id
}

output "name" {
  description = "Name of the managed zone."
  value       = google_dns_managed_zone.this.name
}

output "name_servers" {
  description = "Name servers delegated to this managed zone."
  value       = google_dns_managed_zone.this.name_servers
}

output "dnssec_ds_records" {
  description = "DS records for the zone's key-signing keys. Publish one of these in the parent zone at your registrar to complete the chain of trust. Empty when the zone is private or dnssec_state is off."
  value       = try(data.google_dns_keys.this[0].key_signing_keys[*].ds_record, [])
}
