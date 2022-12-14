# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "backend_id" {
  type = string
}

variable "dns_project" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "enable_cdn" {
  type    = bool
  default = false
}

variable "locations" {
  type = list(string)
}

variable "project" {
  type = string
}

variable "service_domain" {
  type = string
}

variable "service_id" {
  type = string
}

variable "subdomain" {
  type    = string
  default = null
}

variable "suffix" {
  type = string
}