# terraform-google-dns

Terraform module that manages a [Google Cloud](https://cloud.google.com/)
Cloud DNS managed zone (`google_dns_managed_zone`) and an optional set of
record sets driven by a map input.

Public zones are DNSSEC-signed by default, and private zones must be given the
VPC networks they answer queries from.

## Usage

```hcl
module "dns" {
  source = "github.com/moveeeax/terraform-google-dns?ref=v1.0.0"

  project_id = var.project_id
  name       = "prod-zone"
  dns_name   = "example.com."

  records = {
    # Cloud DNS has no alias record type and a CNAME is illegal at a zone apex
    # (RFC 1034), so an apex is pointed at a load balancer with a plain A
    # record holding the balancer's reserved static IP.
    apex = {
      name    = "example.com."
      type    = "A"
      rrdatas = ["203.0.113.10"]
    }

    www = {
      name    = "www.example.com."
      type    = "A"
      ttl     = 60
      rrdatas = ["203.0.113.10"]
    }
  }
}
```

Publish one of `module.dns.dnssec_ds_records` at your registrar, and delegate
the domain to `module.dns.name_servers`. Signing the zone alone does not get it
validated -- the DS record has to reach the parent zone.

### Private zones

A private zone resolves only from the VPC networks authorised on it. Supply
them, or the zone is created and answers nobody:

```hcl
module "internal_dns" {
  source = "github.com/moveeeax/terraform-google-dns?ref=v1.0.0"

  project_id                  = var.project_id
  name                        = "internal-zone"
  dns_name                    = "internal.example.com."
  visibility                  = "private"
  private_visibility_networks = [google_compute_network.this.id]
}
```

The module refuses to plan a private zone with an empty
`private_visibility_networks`, and refuses to plan a public zone that was given
networks (Cloud DNS would silently ignore them).

Runnable examples live in [`examples/basic`](examples/basic) and
[`examples/private`](examples/private).

## Behaviour worth knowing

- **DNSSEC is on by default and only for public zones.** Cloud DNS rejects
  `dnssec_config` on a private zone, so the module omits the block whenever
  `visibility = "private"`, whatever `dnssec_state` says. Set
  `dnssec_state = "off"` if you sign the zone elsewhere.
- **Creating a record overwrites any existing record set with the same name and
  type.** This is the `google` provider's behaviour, not something this module
  can opt out of: on create it lists the zone and deletes colliding record sets
  before adding its own. Nothing appears in the plan. Be careful pointing this
  module at a zone that already holds records, and in particular avoid managing
  the apex `NS` set unless you mean to replace the delegation.
- Because of the above, the module rejects two `records` entries that share a
  name and type (compared case-insensitively): Cloud DNS holds one record set
  per name/type pair, so they would silently clobber each other. Put every
  value for one name/type in a single entry's `rrdatas`.
- Record names must be fully qualified and inside the zone. `"www"` is rejected
  at plan time rather than failing mid-apply; write `"www.example.com."`.
- **`force_destroy` is deliberately not exposed.** Setting it true makes
  destroying the zone delete every record in it, including records this module
  does not manage. Records created by this module are torn down before the zone
  anyway, so it is not needed for an ordinary `terraform destroy`.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| google    | >= 5.0   |

The test suite under [`tests/`](tests) additionally needs Terraform >= 1.7 for
`mock_provider`. The module itself does not.

## Inputs

| Name                          | Description                                                                                       | Type          | Default                  | Required |
|-------------------------------|---------------------------------------------------------------------------------------------------|---------------|--------------------------|:--------:|
| `project_id`                  | ID of the project in which to create the managed zone.                                            | `string`      | n/a                      |   yes    |
| `name`                        | Name of the managed DNS zone.                                                                     | `string`      | n/a                      |   yes    |
| `dns_name`                    | DNS name of the zone, with a trailing dot.                                                        | `string`      | n/a                      |   yes    |
| `description`                 | Description for the managed zone.                                                                 | `string`      | `"Managed by Terraform"` |    no    |
| `visibility`                  | Zone visibility: `public` or `private`.                                                           | `string`      | `"public"`               |    no    |
| `dnssec_state`                | `on`, `off` or `transfer`. Applied to public zones only.                                          | `string`      | `"on"`                   |    no    |
| `private_visibility_networks` | VPC network self-links a private zone answers from. Required when private, must be empty when not. | `list(string)` | `[]`                     |    no    |
| `records`                     | DNS records keyed by id (`name`, `type`, `rrdatas`, optional `ttl` defaulting to 300).            | `map(object)` | `{}`                     |    no    |
| `labels`                      | Labels applied to the managed zone.                                                               | `map(string)` | `{}`                     |    no    |

## Outputs

| Name                | Description                                                                          |
|---------------------|--------------------------------------------------------------------------------------|
| `id`                | Identifier of the managed zone.                                                      |
| `name`              | Name of the managed zone.                                                            |
| `name_servers`      | Name servers delegated to this managed zone.                                         |
| `dnssec_ds_records` | DS records to publish at the registrar. Empty for private or unsigned zones.          |

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test
```

`terraform test` uses a mocked provider, so it needs no GCP credentials.

## License

[MIT](LICENSE)
