# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "content_key" { type = string }
variable "cpu_count" { default = 1}
variable "datastore_namespace" { type = string }
variable "deployers" { type = list(string) }
variable "deployment_env" { type = string }
variable "enable_cdn" { default = false }
variable "encryption_key" { type = string }
variable "http_loglevel" { type = string }
variable "index_key" { type = string  }
variable "ingress" { type = string  }
variable "invokers" {}
variable "locations" { type = list(string) }
variable "project" { type = string }
variable "secrets" { default = [] }
variable "service_account" { type = string }
variable "service_domain" { type = string }
variable "service_id" { type = string }
variable "signing_key" { type = string }
variable "service_project" { type = string }
variable "subscribes" {}
variable "variables" {}

locals {
  primary_location = var.locations[0]
}

data "google_service_account" "default" {
  account_id = var.service_account
}

# Allow the deployers to act as this service account
resource "google_service_account_iam_binding" "deployers" {
  service_account_id  = var.service_account
  role                = "roles/iam.serviceAccountUser"
  members             = var.deployers
}

# Create the Cloud Run service, a backend, network endpoint
# group.
resource "google_cloud_run_service" "default" {
  for_each                    = toset(var.locations)
  project                     = var.project
  name                        = var.service_id
  location                    = each.key
  autogenerate_revision_name  = true

  metadata {
    annotations = {
      "run.googleapis.com/ingress": var.ingress,
    }
    namespace = var.project
  }

  template {
    metadata {
      annotations = {
        "run.googleapis.com/secrets": (length(var.secrets) > 0) ? join(",",
          [
            for spec in var.secrets:
            "${spec.secret}:projects/${spec.project_id}/secrets/${spec.secret}"
          ]
        ) : null
        #SECRET_LOOKUP_NAME:projects/PROJECT_NUMBER/secrets/SECRET_NAME
      }
    }

    spec {
      container_concurrency = 100
      service_account_name  = data.google_service_account.default.email

      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        ports {
          name            = "http1"
          container_port  = 8000
        }

        resources {
          limits = {
            cpu = "${var.cpu_count}000m"
            memory: "512Mi"
          }
        }

        dynamic "env" {
          for_each = toset(keys(var.variables))
          content {
            name  = env.key
            value = var.variables[env.key]
          }
        }

        dynamic "env" {
          for_each = var.secrets
          content {
            name = env.value.name
            value_from {
              secret_key_ref {
                name  = env.value.secret
                key   = "latest"
              }
            }
          }
        }

        env {
          name  = "APP_ENCRYPTION_KEY"
          value = var.encryption_key
        }

        env {
          name  = "APP_SIGNING_KEY"
          value = var.signing_key
        }

        env {
          name  = "DEPLOYMENT_ENV"
          value = var.deployment_env
        }

        # TODO: We assume here that the container is only ever
        # running behind a Google load balancer.
        env {
          name  = "FORWARDED_ALLOW_IPS"
          value = "*"
        }

        env {
          name  = "GOOGLE_DATASTORE_NAMESPACE"
          value = var.datastore_namespace
        }

        env {
          name  = "GOOGLE_HOST_PROJECT"
          value = var.project
        }

        env {
          name  = "GOOGLE_SERVICE_PROJECT"
          value = var.service_project
        }

        env {
          name  = "GOOGLE_SERVICE_ACCOUNT_EMAIL"
          value = data.google_service_account.default.email
        }

        env {
          name  = "HTTP_ALLOWED_HOSTS"
          value = var.service_domain
        }

        env {
          name  = "HTTP_LOGLEVEL"
          value = var.http_loglevel
        }

        env {
          name  = "HTTP_WORKERS"
          value = var.cpu_count
        }

        env {
          name  = "PII_ENCRYPTION_KEY"
          value = var.content_key
        }

        env {
          name  = "PII_INDEX_KEY"
          value = var.index_key
        }

        env {
          name  = "PYTHONUNBUFFERED"
          value = "True"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template.0.spec.0.containers.0.args,
      template.0.spec.0.containers.0.image,
      metadata[0].annotations["client.knative.dev/user-image"],
      metadata[0].annotations["run.googleapis.com/client-name"],
      metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
}

# Create an IAM policy to allow invocation and deployment
# by the deployers.
data "google_iam_policy" "default" {
  binding {
    role    = "roles/run.invoker"
    members = toset(concat(var.invokers, [
			"serviceAccount:${data.google_service_account.default.email}"
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

# Deploy networking resource for use with a load balancer.
resource "google_compute_region_network_endpoint_group" "endpoint" {
  depends_on            = [google_cloud_run_service.default]
  for_each              = google_cloud_run_service.default
  project               = each.value.project
  network_endpoint_type = "SERVERLESS"
  region                = each.value.location
  name                  = each.value.name

  cloud_run {
    service = var.service_id
  }
}

resource "google_compute_backend_service" "default" {
  depends_on  = [google_cloud_run_service.default]
  project     = var.project
  name        = "${var.service_id}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = var.enable_cdn
  custom_response_headers = [
    "Referrer-Policy: no-referrer",
    "Strict-Transport-Security: max-age=15552000; includeSubDomains",
    "X-Content-Type-Options: nosniff",
    "X-Frame-Options: SAMEORIGIN",
  ]

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

# Create Eventarc triggers for each topic to which the service subscribes.
resource "random_string" "eventarc" {
  for_each  = var.subscribes
  length    = 6
  special   = false
  upper     = false
}

resource "google_eventarc_trigger" "events" {
  for_each        = var.subscribes
  project         = google_cloud_run_service.default[local.primary_location].project
  name            = "${var.service_id}-${random_string.eventarc[each.key].result}"
  location        = local.primary_location
  service_account = data.google_service_account.default.email

  matching_criteria {
    attribute = "type"
    value = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_service.default[local.primary_location].name
      region  = google_cloud_run_service.default[local.primary_location].location
      path    = "/.well-known/aorta"
    }
  }

  transport {
    pubsub {
      topic = each.key
    }
  }
}

# Create Eventarc triggers for keepalives
resource "random_string" "keepalive" {
  length      = 6
  special     = false
  upper       = false
  depends_on  = [google_cloud_run_service.default]
  for_each    = toset(var.locations)
}

data "google_pubsub_topic" "keepalive" {
  project = var.project
  name    = "keepalive.${var.service_id}"
}

resource "google_eventarc_trigger" "keepalive" {
  for_each        = toset(var.locations)
  project         = google_cloud_run_service.default[each.key].project
  name            = "keepalive-${random_string.keepalive[each.key].result}"
  location        = google_cloud_run_service.default[each.key].location
  service_account = data.google_service_account.default.email

  matching_criteria {
    attribute = "type"
    value = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_service.default[each.key].name
      region  = google_cloud_run_service.default[each.key].location
      path    = "/.well-known/aorta"
    }
  }

  transport {
    pubsub {
      topic = data.google_pubsub_topic.keepalive.name
    }
  }
}

output "backend_id" {
  value = google_compute_backend_service.default.id
}