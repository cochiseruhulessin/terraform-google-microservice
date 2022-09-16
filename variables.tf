# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "artifact_registry_location" {
  type    = string
  default = null
}

variable "artifact_registry_name" {
  type    = string
  default = null
}

variable "artifact_registry_project" {
  type    = string
  default = null
}

variable "base_domain" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "container_args" {
  default = []
  type    = list(string)
}

variable "cpu_count" {
  type    = number
  default = 1
}

variable "datastore_location" {
  type    = string
  default = null
}

variable "default_log_bucket" {
  type    = string
  default = null
}

variable "default_log_location" {
  type    = string
  default = null
}

variable "deployers" {
  type = list(string)
}

variable "deployment_env" {
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

variable "encryption_key_version" {
  type    = number
  default = 1
}

variable "events" {
  type        = set(string)
  default     = []
  description = "The set of events that this service is interested in."
}

variable "http_loglevel" {
  type    = string
  default = "CRITICAL"
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

variable "keys" {
  type    = list(object({
    protection_level = string
    name = string
    purpose = string
    algorithm = string
  }))
  default = []
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

variable "publishes" {
  type        = set(string)
  default     = []
  description = "The set of events that this service publishes."
}

variable "pubsub_topic_prefix" {
  default = null
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

variable "secret_locations" {
  type = list(string)
}

variable "service_id" {
  type = string
}

variable "service_name" {
  type = string
}

variable "signing_key_version" {
  type    = number
  default = 1
}

variable "subdomain" {
  type    = string
  default = null
}

variable "subscribes" {
  type        = set(string)
  default     = []
  description = "The set of events that this service subscribes to."
}

variable "variables" {
  type    = map(string)
  default = {}
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

variable "with_data_encryption" {
  type        = bool
  default     = false
  description = "If true, create an AES-256 encryption key for data-at-rest encryption."
}