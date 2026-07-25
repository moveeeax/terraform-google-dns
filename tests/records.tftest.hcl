# Test-only requirement: mock_provider needs Terraform >= 1.7 (or OpenTofu >= 1.7).

mock_provider "google" {}

variables {
  project_id = "test-project"
  name       = "test-zone"
  dns_name   = "example.com."
}

run "ttl_defaults_to_300" {
  variables {
    records = {
      apex = {
        # GCP has no alias record type; an apex is pointed at a load balancer
        # with a plain A record to its static IP.
        name    = "example.com."
        type    = "A"
        rrdatas = ["203.0.113.10"]
      }
    }
  }

  assert {
    condition     = google_dns_record_set.this["apex"].ttl == 300
    error_message = "ttl should default to 300 when omitted"
  }

  assert {
    condition     = google_dns_record_set.this["apex"].managed_zone == google_dns_managed_zone.this.name
    error_message = "records must be attached to the zone this module creates"
  }
}

run "explicit_ttl_is_honoured" {
  variables {
    records = {
      www = {
        name    = "www.example.com."
        type    = "A"
        ttl     = 60
        rrdatas = ["203.0.113.10"]
      }
    }
  }

  assert {
    condition     = google_dns_record_set.this["www"].ttl == 60
    error_message = "an explicit ttl must be passed through"
  }
}

# The provider deletes any colliding record set on create, so two entries with
# the same name and type would overwrite each other with no error at all.
run "rejects_duplicate_name_and_type" {
  command = plan

  variables {
    records = {
      a = {
        name    = "www.example.com."
        type    = "A"
        rrdatas = ["203.0.113.10"]
      }
      b = {
        name    = "WWW.example.com."
        type    = "a"
        rrdatas = ["203.0.113.11"]
      }
    }
  }

  expect_failures = [var.records]
}

run "allows_same_name_with_different_types" {
  variables {
    records = {
      v4 = {
        name    = "www.example.com."
        type    = "A"
        rrdatas = ["203.0.113.10"]
      }
      v6 = {
        name    = "www.example.com."
        type    = "AAAA"
        rrdatas = ["2001:db8::1"]
      }
    }
  }

  assert {
    condition     = length(google_dns_record_set.this) == 2
    error_message = "one name may hold several record sets as long as their types differ"
  }
}

run "rejects_empty_rrdatas" {
  command = plan

  variables {
    records = {
      www = {
        name    = "www.example.com."
        type    = "A"
        rrdatas = []
      }
    }
  }

  expect_failures = [var.records]
}

run "rejects_record_outside_the_zone" {
  command = plan

  variables {
    records = {
      www = {
        # The usual mistake: a relative name instead of a fully qualified one.
        name    = "www"
        type    = "A"
        rrdatas = ["203.0.113.10"]
      }
    }
  }

  expect_failures = [google_dns_record_set.this]
}

run "record_names_are_matched_case_insensitively" {
  variables {
    dns_name = "example.com."
    records = {
      www = {
        name    = "WWW.Example.COM."
        type    = "A"
        rrdatas = ["203.0.113.10"]
      }
    }
  }

  assert {
    condition     = google_dns_record_set.this["www"].name == "WWW.Example.COM."
    error_message = "DNS names are case insensitive, so mixed case must be accepted"
  }
}
