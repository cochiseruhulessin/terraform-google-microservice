# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#output "backend_id" {
#  value = google_compute_backend_service.default.id
#}

output "service_id" {
  description = "The service identifier."
  value       = var.service_id
}

output "service_account" {
  description = "The email address of the service account."
  value       = google_service_account.default.email
}

output "project" {
  description = "The service project created for this deployment."
  value       = local.project
}