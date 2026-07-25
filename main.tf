resource "google_dns_managed_zone" "this" {
  project     = var.project_id
  name        = var.name
  dns_name    = var.dns_name
  description = var.description
  visibility  = var.visibility
  labels      = var.labels

  # Cloud DNS only supports DNSSEC on public zones; sending dnssec_config for a
  # private zone is rejected by the API.
  dynamic "dnssec_config" {
    for_each = var.visibility == "public" ? [1] : []

    content {
      state = var.dnssec_state
    }
  }

  # A private zone answers queries only from the VPC networks authorised here.
  # Without this block the zone is created but is visible from no network at
  # all, which makes it silently useless.
  dynamic "private_visibility_config" {
    for_each = var.visibility == "private" ? [1] : []

    content {
      dynamic "networks" {
        for_each = var.private_visibility_networks

        content {
          network_url = networks.value
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.visibility != "private" || length(var.private_visibility_networks) > 0
      error_message = "visibility is \"private\" but private_visibility_networks is empty. A private zone with no authorised VPC networks resolves for nobody; pass at least one network self-link."
    }

    precondition {
      condition     = var.visibility == "private" || length(var.private_visibility_networks) == 0
      error_message = "private_visibility_networks is only meaningful when visibility is \"private\"; it would be silently ignored for a public zone."
    }
  }
}

# Signing a zone achieves nothing until the DS record is published in the
# parent zone at the registrar, so surface it rather than making callers go and
# look it up by hand.
data "google_dns_keys" "this" {
  count = var.visibility == "public" && var.dnssec_state != "off" ? 1 : 0

  project      = var.project_id
  managed_zone = google_dns_managed_zone.this.name
}

resource "google_dns_record_set" "this" {
  for_each = var.records

  project      = var.project_id
  managed_zone = google_dns_managed_zone.this.name
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas

  lifecycle {
    precondition {
      # Cloud DNS rejects a record set whose name is not inside the zone, and
      # the common mistake is passing a relative name such as "www".
      condition     = endswith(lower(each.value.name), lower(var.dns_name))
      error_message = "Record \"${each.key}\" has name \"${each.value.name}\", which is not inside the zone \"${var.dns_name}\". Record names must be fully qualified and end with the zone's dns_name (including the trailing dot)."
    }
  }
}
