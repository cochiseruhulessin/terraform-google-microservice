# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "base_domain" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "deployers" {
  type = list(string)
}

variable "dns_project" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "enable_cdn" {
  type = bool
  default = false
}

variable "ingress" {
  type    = string
  default = "internal-and-cloud-load-balancing"
}

variable "invokers" {
  type = list(string)
  default = ["allUsers"]
}

variable "isolate" {
  type    = bool
  default = true
}

variable "keyring_location" {
  type = string
}

variable "locations" {
  type = list(string)
}

variable "org_id" {
  type = string
}

variable "ping_schedule" {
  type    = string
  default = null
}

variable "project" {
  type    = string
}

variable "secrets" {
  default = []
  type    = list(
    object({
      name = string
      secret = string
    })
  )
}

variable "service_id" {
  type = string
}

variable "service_name" {
  type = string
}

variable "subdomain" {
  type    = string
  default = null
}

variable "with_domain_map" {
  type    = bool
  default = false
}

variable "with_loadbalancer" {
  type    = bool
  default = false
}

variable "with_dns" {
  type    = bool
  default = false
}