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

locals {
  project = (var.isolate) ? google_project.service[0].project_id : var.project
  service_domain = "${var.service_id}.${var.base_domain}"
  suffix = {
    for location, spec in random_string.locations:
    location => spec.result
  }
  secrets = {for spec in var.secrets: spec.name => spec.secret}
}

# Generate a random suffic for the service-specific project and create
# a project holding the resources specific to this service.
resource "random_string" "project_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "google_project" "service" {
  count           = (var.isolate) ? 1 : 0
  name            = var.service_name
  project_id      = "${var.project}-${random_string.project_suffix.result}"
  billing_account = var.billing_account
  org_id          = var.org_id
}

resource "google_project_service" "required" {
  for_each = toset([
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  project            = local.project
  service            = each.key
  disable_on_destroy = false

  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Create a random suffix for each location, to prevent
# resource name clashes.
resource "random_string" "locations" {
  for_each  = toset(var.locations)
  length    = 6
  special   = false
  upper     = false
}


# Create the service account that is used by the service to
# access resources.
resource "random_string" "service_account" {
  length    = 6
  special   = false
  upper     = false
}

resource "google_service_account" "default" {
  project  = local.project
  account_id    = "${var.service_id}-${random_string.service_account.result}"
  display_name  = var.service_name
}

# Allow the deployers to act as this service account
resource "google_service_account_iam_binding" "deployers" {
  service_account_id  = google_service_account.default.name
  role                = "roles/iam.serviceAccountUser"
  members             = var.deployers
}

# By default, the service has a signing keypair that it
# uses to identify itself, and an asymmetric encryption
# key to encrypt data.
resource "google_kms_key_ring" "default" {
  depends_on = [google_project_service.required]
  project    = local.project
  name       = "${var.service_id}-${random_string.project_suffix.result}"
  location   = var.keyring_location
}

resource "google_kms_key_ring_iam_binding" "viewer" {
  key_ring_id = google_kms_key_ring.default.id
  role        = "roles/cloudkms.viewer"
  members     = ["serviceAccount:${google_service_account.default.email}"]
}

resource "google_kms_key_ring_iam_binding" "operator" {
  key_ring_id = google_kms_key_ring.default.id
  role        = "roles/cloudkms.cryptoOperator"
  members     = ["serviceAccount:${google_service_account.default.email}"]
}

resource "google_kms_crypto_key" "sig" {
  depends_on      = [google_kms_key_ring.default]
  name            = "sig"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ASYMMETRIC_SIGN"

  version_template {
    algorithm         = "EC_SIGN_P384_SHA384"
    protection_level  = "SOFTWARE"
  }
}

resource "google_kms_crypto_key" "enc" {
  depends_on      = [google_kms_key_ring.default]
  name            = "enc"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ASYMMETRIC_DECRYPT"

  version_template {
    algorithm         = "RSA_DECRYPT_OAEP_3072_SHA256"
    protection_level  = "SOFTWARE"
  }
}

# Create secrets and allow the service to access them.
resource "google_secret_manager_secret" "secrets" {
  depends_on  = [google_project_service.required]
  for_each    = local.secrets
  project     = local.project
  secret_id   = each.value

  replication {
    user_managed {
      dynamic "replicas" {
        for_each = toset(var.locations)
        content {
          location = replicas.key
        }
      }
    }
  }
}

resource "google_secret_manager_secret_version" "initial" {
  depends_on  = [google_project_service.required]
  for_each    = local.secrets
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = "changeme"

  lifecycle {
    ignore_changes = [enabled, secret_data]
  }
}

resource "google_secret_manager_secret_iam_binding" "secretAccessor" {
  depends_on  = [google_project_service.required]
  for_each    = local.secrets
  project     = google_secret_manager_secret.secrets[each.key].project
  secret_id   = google_secret_manager_secret.secrets[each.key].secret_id
  role        = "roles/secretmanager.secretAccessor"
  members     = ["serviceAccount:${google_service_account.default.email}"]
}

# Create the Cloud Run service, a backend, network endpoint
# group.
resource "google_cloud_run_service" "default" {
  depends_on = [google_project_service.required]
  for_each  = toset(var.locations)
  project   = local.project
  name      = var.service_id
  location  = each.key

  metadata {
    annotations = {
      "run.googleapis.com/ingress": var.ingress
    }
    namespace = local.project
  }

  template {
    spec {
      container_concurrency = 100
      service_account_name  = google_service_account.default.email

      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        ports {
          name            = "http1"
          container_port  = 8000
        }

        dynamic "env" {
          for_each = local.secrets
          content {
            name = env.key
            value_from {
              secret_key_ref {
                name  = env.value
                key   = "latest"
              }
            }
          }
        }

        # TODO: We assume here that the container is only ever
        # running behind a Google load balancer.
        env {
          name  = "FORWARDED_ALLOW_IPS"
          value = "*"
        }

        env {
          name  = "HTTP_LOGLEVEL"
          value = "CRITICAL"
        }
      }
    }
  }
}

# Create an IAM policy to allow invocation and deployment
# by the deployers.
data "google_iam_policy" "default" {
  binding {
    role    = "roles/run.invoker"
    members = toset(concat(var.invokers, [
			"serviceAccount:${google_service_account.default.email}"
		]))
  }

  binding {
    role    = "roles/run.developer"
    members = var.deployers
  }
}

resource "google_cloud_run_service_iam_policy" "default" {
  for_each    = google_cloud_run_service.default
  location    = each.value.location
  project     = each.value.project
  service     = each.value.name
  policy_data = data.google_iam_policy.default.policy_data
}

resource "google_compute_region_network_endpoint_group" "endpoint" {
  depends_on            = [google_project_service.required]
  for_each              = toset(var.locations)
  project               = local.project
  network_endpoint_type = "SERVERLESS"
  region                = each.key
  name                  = "cloudrun-${var.service_id}"

  cloud_run {
    service = var.service_id
  }
}

resource "google_compute_backend_service" "default" {
  depends_on  = [google_project_service.required]
  project     = local.project
  name        = "cloudrun-${var.service_id}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = var.enable_cdn

  dynamic "cdn_policy" {
    for_each = (var.enable_cdn) ? [null] : []
    content {
      cache_mode                    = "USE_ORIGIN_HEADERS"
      signed_url_cache_max_age_sec  = 7200
    }
  }

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.endpoint

    content {
      group = backend.value.self_link
    }
  }

  log_config {
    enable = true
  }
}

# Public routing of the service. Can be a domain map or a load balancer.
module "domain-map" {
  depends_on      = [google_project_service.required]
  count           = (var.with_domain_map) ? 1 : 0
  source          = "./modules/domain-map"
  dns_project     = var.dns_project
  dns_zone        = var.dns_zone
  locations       = var.locations
  project         = local.project
  services        = [
    for spec in google_cloud_run_service.default:
    {location = spec.location, name = spec.name, project = spec.project}
  ]
  service_domain  = local.service_domain
}

module "loadbalancer" {
  depends_on      = [google_project_service.required]
  count           = (var.with_loadbalancer) ? 1 : 0
  backend_id      = google_compute_backend_service.default.id
  source          = "./modules/loadbalancer"
  acme_email      = "${var.project}+${var.service_id}@services.ops.unimatrixone.io"
  dns_project     = var.dns_project
  dns_zone        = var.dns_zone
  locations       = var.locations
  project         = local.project
  service_domain  = local.service_domain
  service_id      = var.service_id
  subdomain       = var.subdomain
  suffix          = random_string.project_suffix.result
}