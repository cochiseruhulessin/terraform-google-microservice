# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "destination" {
  type = string
}

variable "project" {
  type = string
}

variable "service_project" {
  type = string
}


resource "google_logging_project_sink" "default" {
  project                 = var.service_project
  name                    = "default"
  description             = "Default service logs"
  destination             = var.destination
  unique_writer_identity  = true
  filter                  = "resource.type = cloud_run_revision"
}

resource "google_project_iam_member" "writer" {
  for_each = toset([
    "roles/logging.bucketWriter",
    "roles/logging.logWriter",
    "roles/storage.objectCreator"
  ])
  project = var.project
  role    = each.key
  member  = google_logging_project_sink.default.writer_identity
}