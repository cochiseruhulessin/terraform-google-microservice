# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

# Create a bucket to hold the assets and a corresponding backend
# service with the proper headers configured.
resource "google_storage_bucket" "frontend" {
  count                       = (var.frontend) ? 1 : 0
  project                     = var.project
  name                        = var.service_domain
  location                    = "EU"
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page = "index.html"
  }
}

resource "google_storage_bucket_iam_binding" "frontend" {
  depends_on = [google_storage_bucket.frontend]
  for_each = {for spec in google_storage_bucket.frontend: spec.name => spec}
  bucket = each.value.name
  role = "roles/storage.legacyObjectReader"
  members = ["allUsers"]
}

resource "google_compute_backend_bucket" "frontend" {
  depends_on  = [google_storage_bucket.frontend]
  for_each    = {for spec in google_storage_bucket.frontend: spec.name => spec}
  project     = var.project
  name        = "${var.service_id}-frontend"
  description = "Backend bucket for ${var.service_id}"
  bucket_name = each.key
  enable_cdn  = false

  # We don't trust the browser code, but this still leaves a too large
  # attack surface (TODO).
  custom_response_headers = [
    #"Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'",
    "Referrer-Policy: no-referrer",
    "Strict-Transport-Security: max-age=15552000; includeSubDomains",
    "X-Content-Type-Options: nosniff",
    "X-Frame-Options: SAMEORIGIN",
  ]
}

resource "google_compute_url_map" "default" {
  project         = var.project
  name            = "service-${var.service_id}"
  default_service = (var.frontend) ? google_compute_backend_bucket.frontend[var.service_domain].id : var.backend_id

  dynamic "host_rule" {
    for_each = (var.frontend == false) ? toset([]) : toset([var.service_domain])
    content {
      hosts = concat([host_rule.key], var.accepted_hosts)
      path_matcher = "default"
    }
  }

  dynamic "path_matcher" {
    for_each = (var.frontend == false) ? toset([]) : toset([var.service_domain])
    content {
      name = "default"
      default_service = google_compute_backend_bucket.frontend[var.service_domain].id

      path_rule {
        paths   = coalesce(var.backend_paths, ["/api", "/api/*"])
        service = var.backend_id

        route_action {
          url_rewrite {
            path_prefix_rewrite = (var.backend_paths != null) ? null : "/"
          }
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_address" "ipv4" {
  project    = var.project
  provider   = google
  name       = "service-${var.service_id}"
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
  count         = (var.dns_zone != null) ? 1 : 0
  managed_zone  = var.dns_zone
  project       = coalesce(var.dns_project, var.project)
  name          = "${var.service_domain}."
  type          = "A"
  ttl           = 60
  rrdatas       = [google_compute_global_address.ipv4.address]
}