# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# Create an ACME registration with Lets Encrypt for this specific
# service and obtain a certificate. Create a Google SSL certificate
# for use with the load balancer.
terraform {
  required_providers {
    acme = {
      source = "vancluever/acme"
      version = "2.6.0"
    }
  }
}

variable "acme_email" {
  type = string
}

variable "dns_project" {
  type = string
}

variable "project" {
  type = string
}

variable "service_domain" {
  type = string
}

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

output "resource_id" {
  value = google_compute_ssl_certificate.tls.self_link
}