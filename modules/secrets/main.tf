# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "locations" {}
variable "project" {}
variable "secrets" {}
variable "service_account" {}


data "google_project" "svc" {
  project_id = var.project
}

resource "google_secret_manager_secret" "secrets" {
  for_each    = var.secrets
  project     = var.project
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
  for_each    = var.secrets
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = "changeme"

  lifecycle {
    ignore_changes = [enabled, secret_data]
  }
}

resource "google_secret_manager_secret_iam_binding" "secretAccessor" {
  for_each    = var.secrets
  project     = google_secret_manager_secret.secrets[each.key].project
  secret_id   = google_secret_manager_secret.secrets[each.key].secret_id
  role        = "roles/secretmanager.secretAccessor"
  members     = ["serviceAccount:${var.service_account}"]
}

output "secrets" {
  value = [
    for name, secret in var.secrets: {
      name       = name,
      secret     = secret,
      project_id = data.google_project.svc.number
    }
  ]
}