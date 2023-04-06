# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "bucket_name" { type = string }
variable "bucket_location" { type = string}
variable "project" { type = string }
variable "service_account" { type = string }


resource "google_storage_bucket" "app" {
  force_destroy               = true
  location                    = var.bucket_location
  name                        = var.bucket_name
  project                     = var.project
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.app.name
  role = "roles/storage.admin"
  member = "serviceAccount:${var.service_account}"
}

output "bucket_name" {
  value = google_storage_bucket.app.name
}