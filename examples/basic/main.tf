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

# A public zone. DNSSEC is on by default; publish one of the DS records from
# the dnssec_ds_records output at your registrar to finish the chain of trust.
module "dns" {
  source = "../.."

  project_id = var.project_id
  name       = "example-zone"
  dns_name   = "example.com."

  records = {
    # Cloud DNS has no alias record type, and a CNAME is illegal at a zone
    # apex (RFC 1034), so an apex is pointed at a load balancer with a plain A
    # record holding the balancer's reserved static IP.
    apex = {
      name    = "example.com."
      type    = "A"
      rrdatas = [var.load_balancer_ip]
    }

    www = {
      name    = "www.example.com."
      type    = "A"
      rrdatas = [var.load_balancer_ip]
    }

    # ttl is optional and defaults to 300.
    mail = {
      name    = "example.com."
      type    = "MX"
      ttl     = 3600
      rrdatas = ["10 mail.example.com."]
    }
  }

  labels = {
    environment = "example"
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

variable "load_balancer_ip" {
  description = "Reserved global static IP of the load balancer the apex points at."
  type        = string
  default     = "203.0.113.10"
}

output "zone_name_servers" {
  description = "Delegate the domain to these name servers at your registrar."
  value       = module.dns.name_servers
}

output "dnssec_ds_records" {
  description = "Publish one of these DS records at your registrar to enable DNSSEC validation."
  value       = module.dns.dnssec_ds_records
}
