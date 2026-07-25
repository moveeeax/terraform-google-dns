variable "project_id" {
  description = "ID of the project in which to create the managed zone."
  type        = string
}

variable "name" {
  description = "Name of the managed DNS zone."
  type        = string
}

variable "dns_name" {
  description = "DNS name of the zone, ending with a trailing dot (e.g. example.com.)."
  type        = string

  validation {
    condition     = can(regex("\\.$", var.dns_name))
    error_message = "dns_name must end with a trailing dot."
  }
}

variable "description" {
  description = "Description for the managed zone."
  type        = string
  default     = "Managed by Terraform"
}

variable "visibility" {
  description = "Zone visibility: public or private."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be either public or private."
  }
}

variable "dnssec_state" {
  description = "DNSSEC state for the zone: on, off or transfer. Only applied when visibility is public, because Cloud DNS does not support DNSSEC on private zones. Signing a zone is not enough on its own -- the DS record produced by the provider still has to be published at the registrar before resolvers will validate it."
  type        = string
  default     = "on"

  validation {
    condition     = contains(["on", "off", "transfer"], var.dnssec_state)
    error_message = "dnssec_state must be one of on, off or transfer."
  }
}

variable "private_visibility_networks" {
  description = "Self-links of the VPC networks a private zone answers queries from (e.g. projects/p/global/networks/default). Required when visibility is private, and must be empty otherwise."
  type        = list(string)
  default     = []
}

variable "records" {
  description = "DNS records to create, keyed by an arbitrary id. Each entry sets name (fully qualified, inside the zone), type, rrdatas and an optional ttl."
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    rrdatas = list(string)
  }))
  default = {}

  validation {
    # Cloud DNS stores one record set per (name, type) pair, and the provider
    # deletes any colliding set on create. Two entries sharing a name and type
    # would therefore overwrite each other with no error and no plan diff.
    condition     = length(distinct([for r in var.records : "${lower(r.name)} ${upper(r.type)}"])) == length(var.records)
    error_message = "Two entries in records share the same name and type. Cloud DNS holds a single record set per name/type pair, so they would silently overwrite each other -- merge their rrdatas into one entry instead."
  }

  validation {
    condition     = alltrue([for r in var.records : length(r.rrdatas) > 0])
    error_message = "Every entry in records must have at least one value in rrdatas."
  }
}

variable "labels" {
  description = "Labels applied to the managed zone."
  type        = map(string)
  default     = {}
}
