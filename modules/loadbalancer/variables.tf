# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "accepted_hosts" {
  type        = list(string)
}

variable "backend_id" {
  type = string
}

variable "backend_paths" {
  type    = list(string)
  default = []
}

variable "buckets" {
  default = {}
}

variable "dns_project" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "domains" {
  default     = []
  type        = list(string)
}

variable "enable_cdn" {
  type    = bool
  default = false
}

variable "frontend" {
  type = bool
}

variable "locations" {
  type = list(
    object({
      name=string
      vpc_access_connector=string
      vpc_access_egress=string
    })
  )
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

variable "suffix" {
  type = string
}
