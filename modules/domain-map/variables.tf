# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "dns_project" {
  type = string
}

variable "dns_zone" {
  type = string
}

variable "locations" {
  type = list(string)
}

variable "project" {
  type = string
}

variable "services" {
  type = list(
    object({
      project   = string
      name      = string
      location  = string
    })
  )
}

variable "service_domain" {
  type = string
}