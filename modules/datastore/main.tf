# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
resource "google_app_engine_application" "app" {
  project       = var.project
  location_id   = var.datastore_location
  database_type = "CLOUD_DATASTORE_COMPATIBILITY"
}

resource "google_project_iam_member" "project" {
  project = var.project
  role    = "roles/datastore.user"
  member  = "serviceAccount:${var.service_account}"
}
