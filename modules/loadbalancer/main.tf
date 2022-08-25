# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
terraform {
  required_providers {
    tls = {
      version = "3.1.0"
    }
  }
}

#module "acme" {
#  count           = (var.certificate_issuer == "letsencrypt") ? 1 : 0
#  acme_email      = var.acme_email
#  dns_project     = var.dns_project
#  project         = var.project
#  service_domain  = var.service_domain
#  source          = "./modules/acme"
#}

resource "google_compute_url_map" "default" {
  project         = var.project
  name            = "service-${var.service_id}"
  default_service = var.backend_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_address" "ipv4" {
  project    = var.project
  provider   = google
  name       = "service-${var.service_id}-${var.suffix}"
}

resource "google_compute_managed_ssl_certificate" "default" {
  project = var.project 
  name    = "${var.service_id}-${var.suffix}"

  lifecycle {
    create_before_destroy = true
  }

  managed {
    domains = ["${var.service_domain}."]
  }
}

resource "google_compute_target_https_proxy" "default" {
  depends_on       = [
    google_compute_url_map.default,
    google_compute_managed_ssl_certificate.default
  ]
  project          = var.project
  provider         = google
  name             = "service-${var.service_id}-${var.suffix}"
  url_map          = google_compute_url_map.default.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  provider              = google
  project               = var.project
  name                  = "service-${var.service_id}-${var.suffix}"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.ipv4.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.self_link
}

resource "google_dns_record_set" "dns" {
  managed_zone  = var.dns_zone
  project       = var.dns_project
  name          = "${var.service_domain}."
  type          = "A"
  ttl           = 60
  rrdatas       = [google_compute_global_address.ipv4.address]
}