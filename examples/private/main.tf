terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "example-dns-vpc"
  auto_create_subnetworks = false
}

# A private zone is only resolvable from the VPC networks authorised on it, so
# private_visibility_networks is mandatory when visibility is "private".
# DNSSEC is not applied here: Cloud DNS does not support it on private zones.
module "dns" {
  source = "../.."

  project_id                  = var.project_id
  name                        = "example-internal-zone"
  dns_name                    = "internal.example.com."
  visibility                  = "private"
  private_visibility_networks = [google_compute_network.this.id]

  records = {
    api = {
      name    = "api.internal.example.com."
      type    = "A"
      ttl     = 60
      rrdatas = ["10.0.0.10"]
    }
  }
}

variable "project_id" {
  description = "Project ID to deploy the example managed zone into."
  type        = string
}

variable "region" {
  description = "Region for the google provider."
  type        = string
  default     = "us-central1"
}

output "zone_id" {
  description = "Identifier of the private managed zone."
  value       = module.dns.id
}
