# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
output "loadbalancer_ipv4_addresses" {
  description = "Public IPv4 addresses of the service."
  value       = toset(module.loadbalancer[0].loadbalancer_ipv4_addresses)
}

output "service_id" {
  description = "The service identifier."
  value       = var.service_id
}

output "service_account" {
  description = "The email address of the service account."
  value       = google_service_account.default.email
}

output "service_domain" {
  description = "The domain name of the service."
  value       = local.service_domain
}

output "project" {
  description = "The service project created for this deployment."
  value       = local.project
}