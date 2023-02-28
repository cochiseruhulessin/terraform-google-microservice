# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
data "google_pubsub_topic" "events" {
  for_each  = var.subscribes
  project   = var.service_project
  name      = each.key
}

# Create a topic and subscription for command messages issued by
# this application.
resource "google_pubsub_topic" "commands" {
  project = var.service_project
  name    = "${var.project_prefix}.commands.${var.service_id}"
}

resource "google_pubsub_topic_iam_member" "commands" {
  depends_on    = [google_pubsub_topic.commands]
  project       = google_pubsub_topic.commands.project
  topic         = google_pubsub_topic.commands.name
  role          = "roles/pubsub.publisher"
  member        = "serviceAccount:${var.service_account}"
}

# Create a topic and subscription for errored messages.
resource "google_pubsub_topic" "retrying" {
  project = var.service_project
  name    = "${var.project_prefix}.retry.${var.service_id}"
}

resource "google_pubsub_topic_iam_member" "retrying" {
  depends_on    = [google_pubsub_topic.retrying]
  project       = google_pubsub_topic.retrying.project
  topic         = google_pubsub_topic.retrying.name
  role          = "roles/pubsub.publisher"
  member        = "serviceAccount:${var.service_account}"
}


#
#resource "random_string" "commands" {
#  length    = 6
#  special   = false
#  upper     = false
#}
#
#resource "google_pubsub_subscription" "commands" {
#  project                 = var.service_project
#  topic                   = google_pubsub_topic.commands.id
#  name                    = "${var.service_id}-${random_string.commands.result}"
#  ack_deadline_seconds    = 60
#  enable_message_ordering = true
#
#  push_config {
#    push_endpoint = var.endpoint
#
#    oidc_token {
#      audience              = var.audience 
#      service_account_email = var.service_account
#    }
#  }
#
#  retry_policy {
#    minimum_backoff = "10s"
#  }
#}

# Create a subscription in the host project that pushed to the
# specified endpoint.
resource "random_string" "subscriptions" {
  for_each  = var.subscribes
  length    = 6
  special   = false
  upper     = false
}

resource "google_pubsub_topic_iam_member" "events" {
  for_each      = var.publishes 
  project       = var.service_project
  topic         = each.key
  role          = "roles/pubsub.publisher"
  member        = "serviceAccount:${var.service_account}"
}

output "command_topic" {
  value = google_pubsub_topic.commands.name
}