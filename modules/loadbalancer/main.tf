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
    acme = {
      source = "vancluever/acme"
      version = "2.6.0"
    }
    tls = {
      version = "3.1.0"
    }
  }
}

# Create an ACME registration with Lets Encrypt for this specific
# service and obtain a certificate. Create a Google SSL certificate
# for use with the load balancer.
resource "tls_private_key" "acme" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "acme_registration" "default" {
  account_key_pem = tls_private_key.acme.private_key_pem
  email_address   = var.acme_email
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "csr" {
  depends_on = [tls_private_key.server]
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.server.private_key_pem
  dns_names       = [var.service_domain]

  subject {
    country             = "NL"
    province            = "Gelderland"
    locality            = "Wezep"
    organization        = "Unimatrix One B.V."
    organizational_unit = "PKI"
    common_name         = var.service_domain
  }
}

resource "acme_certificate" "crt" {
  depends_on              = [tls_private_key.server, acme_registration.default]
  account_key_pem         = tls_private_key.acme.private_key_pem
  certificate_request_pem = tls_cert_request.csr.cert_request_pem
  min_days_remaining      = 30
  recursive_nameservers   = ["8.8.8.8:53"]

  dns_challenge {
    provider = "gcloud"

    config = {
      GCE_PROJECT = var.dns_project
    }
  }
}

resource "google_compute_ssl_certificate" "tls" {
  depends_on  = [tls_private_key.server]
  project     = var.project
  private_key = tls_private_key.server.private_key_pem
  certificate = "${acme_certificate.crt.certificate_pem}${acme_certificate.crt.issuer_pem}"

  lifecycle {
    create_before_destroy = true
  }
}

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

resource "google_compute_target_https_proxy" "default" {
  depends_on       = [google_compute_url_map.default]
  project          = var.project
  provider         = google
  name             = "service-${var.service_id}-${var.suffix}"
  url_map          = google_compute_url_map.default.self_link
  ssl_certificates = [
    google_compute_ssl_certificate.tls.self_link
  ]
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