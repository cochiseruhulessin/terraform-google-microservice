# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "audience" {
  type        = string
  description = "The audience of push messages."
} 

variable "endpoint" {
  type        = string
  description = "The endpoint to push event messages to."
}

variable "events" {
  type        = set(string)
  default     = []
  description = "The set of events that this service is interested in."
}

variable "project_prefix" {
  type        = string
}

variable "publishes" {
  type        = set(string)
  default     = []
}

variable "service_account" {
  type        = string
  description = "The service account that signs the messages."
}

variable "service_id" {
  type        = string
  description = "The service identifier."
}

variable "service_project" {
  type        = string
  description = "The service project in which the service is deployed."
}

variable "subscribes" {
  type        = set(string)
  default     = []
}