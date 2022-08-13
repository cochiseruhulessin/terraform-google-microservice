# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
data "google_pubsub_topic" "events" {
  for_each  = var.events
  project   = var.host_project
  name      = each.key
}

# Create a subscription in the host project that is mirrored to the
# service project using dataflow.
resource "random_string" "subscriptions" {
  for_each  = var.events
  length    = 6
  special   = false
  upper     = false
}

resource "google_pubsub_subscription" "events" {
  for_each                = var.events
  project                 = var.service_project
  topic                   = data.google_pubsub_topic.events[each.key].id
  name                    = "${var.service_id}-${random_string.subscriptions[each.key].result}"
  ack_deadline_seconds    = 60
  enable_message_ordering = true

  push_config {
    push_endpoint = var.endpoint

    oidc_token {
      audience              = var.audience 
      service_account_email = var.service_account
    }
  }

  retry_policy {
    minimum_backoff = "10s"
  }
}

resource "google_pubsub_topic_iam_member" "events" {
  depends_on    = [google_pubsub_subscription.events]
  for_each      = var.events 
  project       = var.host_project
  topic         = each.key
  role          = "roles/pubsub.publisher"
  member        = "serviceAccount:${var.service_account}"
}