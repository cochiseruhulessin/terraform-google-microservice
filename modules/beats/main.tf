# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "command_name" { type = string }
variable "command_topic" { type = string }
variable "name" { type = string }
variable "params" { type = any }
variable "project" { type = string }
variable "schedule" { type = string }


locals {
  command = jsonencode({
    apiVersion  = "v1"
    kind        = var.command_name
    type        = "unimatrixone.io/command"
    spec        = var.params
  })
}


data "google_pubsub_topic" "commands" {
  project = var.project
  name    = var.command_topic
}

resource "google_cloud_scheduler_job" "commands" {
  project           = var.project
  name              = var.name
  description       = "Issues the command ${var.command_name}"
  schedule          = var.schedule
  region            = "europe-west3"

  pubsub_target {
    topic_name = data.google_pubsub_topic.commands.id
    data       = base64encode(local.command)
  }
}
