# Test-only requirement: mock_provider needs Terraform >= 1.7 (or OpenTofu >= 1.7).
# The module itself still supports >= 1.5 -- do not bump required_version for this.

mock_provider "google" {}

variables {
  project_id = "test-project"
  name       = "test-zone"
  dns_name   = "example.com."
}

run "public_zone_is_signed_by_default" {
  assert {
    condition     = google_dns_managed_zone.this.visibility == "public"
    error_message = "visibility should default to public"
  }

  assert {
    condition     = length(google_dns_managed_zone.this.dnssec_config) == 1
    error_message = "a public zone must emit a dnssec_config block"
  }

  assert {
    condition     = google_dns_managed_zone.this.dnssec_config[0].state == "on"
    error_message = "DNSSEC must be on by default for public zones"
  }

  assert {
    condition     = length(data.google_dns_keys.this) == 1
    error_message = "the DS records of a signed public zone must be readable so they can be published at the registrar"
  }
}

run "public_zone_has_no_private_visibility_config" {
  assert {
    condition     = length(google_dns_managed_zone.this.private_visibility_config) == 0
    error_message = "a public zone must not carry a private_visibility_config block"
  }
}

run "dnssec_can_be_turned_off_explicitly" {
  variables {
    dnssec_state = "off"
  }

  assert {
    condition     = google_dns_managed_zone.this.dnssec_config[0].state == "off"
    error_message = "dnssec_state should be honoured"
  }

  assert {
    condition     = length(data.google_dns_keys.this) == 0
    error_message = "an unsigned zone has no DS records to read"
  }
}

run "rejects_invalid_dnssec_state" {
  command = plan

  variables {
    dnssec_state = "enabled"
  }

  expect_failures = [var.dnssec_state]
}

run "rejects_invalid_visibility" {
  command = plan

  variables {
    visibility = "internal"
  }

  expect_failures = [var.visibility]
}

run "rejects_dns_name_without_trailing_dot" {
  command = plan

  variables {
    dns_name = "example.com"
  }

  expect_failures = [var.dns_name]
}

run "private_zone_authorises_its_networks" {
  variables {
    visibility = "private"
    dns_name   = "internal.example.com."
    private_visibility_networks = [
      "projects/test-project/global/networks/vpc-a",
      "projects/test-project/global/networks/vpc-b",
    ]
  }

  assert {
    condition     = length(google_dns_managed_zone.this.private_visibility_config) == 1
    error_message = "a private zone must emit a private_visibility_config block"
  }

  assert {
    condition = toset([for n in google_dns_managed_zone.this.private_visibility_config[0].networks : n.network_url]) == toset([
      "projects/test-project/global/networks/vpc-a",
      "projects/test-project/global/networks/vpc-b",
    ])
    error_message = "every VPC network passed in must be authorised on the zone"
  }

  assert {
    condition     = length(google_dns_managed_zone.this.dnssec_config) == 0
    error_message = "Cloud DNS rejects dnssec_config on private zones, so the block must be omitted"
  }
}

run "private_zone_without_networks_is_rejected" {
  command = plan

  variables {
    visibility                  = "private"
    dns_name                    = "internal.example.com."
    private_visibility_networks = []
  }

  expect_failures = [google_dns_managed_zone.this]
}

run "networks_on_a_public_zone_are_rejected" {
  command = plan

  variables {
    visibility                  = "public"
    private_visibility_networks = ["projects/test-project/global/networks/vpc-a"]
  }

  expect_failures = [google_dns_managed_zone.this]
}
