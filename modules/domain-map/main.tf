# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
locals {
  services = {for spec in var.services: spec.location => spec}
}

data "google_dns_managed_zone" "zone" {
  project = var.dns_project
  name    = var.dns_zone
}

resource "google_cloud_run_domain_mapping" "default" {
  for_each  = local.services
  project   = each.value.project
  location  = each.value.location
  name      = "${(length(var.locations) > 1) ? "${each.value.location}." : ""}${var.service_domain}"

  metadata {
    namespace = var.project
  }

  spec {
    route_name = each.value.name
  }
}

resource "google_dns_record_set" "dns" {
  depends_on    = [google_cloud_run_domain_mapping.default]
  for_each      = merge([
    for spec in google_cloud_run_domain_mapping.default: {
      for record in spec.status[0].resource_records:
        "${spec.location}/${record.name}" => record
    }
  ]...)
  managed_zone  = data.google_dns_managed_zone.zone.name
  project       = data.google_dns_managed_zone.zone.project
  name          = "${each.value.name}.${data.google_dns_managed_zone.zone.dns_name}"
  type          = each.value.type
  ttl           = 60
  rrdatas       = [each.value.rrdata]
}