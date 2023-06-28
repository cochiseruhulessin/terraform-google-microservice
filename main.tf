# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
terraform {
  required_providers {
    tls = {
      version = "3.1.0"
    }
  }
}

locals {
  primary_location    = var.locations[0]
  project             = google_project.service.project_id
  service_account     = "${var.project_prefix}-${var.service_id}"
  service_domain      = coalesce(var.service_domain, "${var.service_id}.${var.base_domain}")
  secrets             = {for spec in var.secrets: spec.name => spec}
  services_project_id = "${var.project}-svc"
  sql_databases       = {for spec in var.sql_databases: spec.name => spec}
  triggers            = {
    for params in setproduct(toset(var.locations), toset(var.events)):
      "${params[1]}/${params[0]}" => {
        location  = params[0]
        topic     = params[1]
      }
  }
}

# Generate a random suffic for the service-specific project and create
# a project holding the resources specific to this service.
resource "random_string" "project_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "google_project" "service" {
  name            = var.service_name
  project_id      = "${coalesce(var.project_prefix, var.project)}-${random_string.project_suffix.result}"
  billing_account = var.billing_account
  org_id          = var.org_id
}

resource "google_project_service" "required" {
  for_each = toset(
    concat([
      "cloudkms.googleapis.com",
      "cloudscheduler.googleapis.com",
      "compute.googleapis.com",
      "dns.googleapis.com",
      "eventarc.googleapis.com",
      "run.googleapis.com",
      "secretmanager.googleapis.com",
    ],
    (var.datastore_location != null) ? ["datastore.googleapis.com"] : []
  ))
  project            = local.project
  service            = each.key
  disable_on_destroy = false

  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Create a random suffix for each location, to prevent
# resource name clashes.
# resource "random_string" "locations" {
#   for_each  = toset(var.locations)
#   length    = 6
#   special   = false
#   upper     = false
# }


# # Create the service account that is used by the service to
# # access resources.
# resource "random_string" "service_account" {
#   length    = 6
#   special   = false
#   upper     = false
# }

resource "google_service_account" "default" {
  project       = local.services_project_id
  account_id    = local.service_account
  display_name  = var.service_name
}

resource "google_project_iam_member" "token-creator" {
  project = local.services_project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "time_rotating" "service-account" {
  rotation_days = 30
}

resource "google_service_account_key" "default" {
  count               = (var.mount_service_account_key) ? 1 : 0
  service_account_id  = google_service_account.default.name

  keepers = {
    rotation_time = time_rotating.service-account.rotation_rfc3339
  }
}

resource "google_project_iam_member" "logging" {
  depends_on = [google_project.service]
  project = google_project.service.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "logging-public" {
  project = local.services_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "secretAccessor" {
  project = local.project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.default.email}"
}

module "crypto" {
  source          = "./modules/kms"
  location        = var.keyring_location
  name            = "${var.service_id}-${random_string.project_suffix.result}"
  project         = google_project.service.project_id
  service_account = google_service_account.default.email

  depends_on = [
    google_project.service,
    google_project_service.required,
    google_service_account.default
  ]
}

module "storage" {
  count             = (var.storage_bucket != null) ? 1 : 0
  source            = "./modules/storage"
  bucket_name       = var.storage_bucket
  bucket_location   = "EU"
  domains           = concat(var.domains, (var.service_domain != null) ? [var.service_domain] : [])
  project           = google_project.service.project_id
  service_account   = google_service_account.default.email
}

module "sql" {
  depends_on  = [google_project_service.required]
  for_each    = local.sql_databases
  master      = each.value.master
  name        = each.value.name
  project     = local.services_project_id
  replicas    = each.value.replicas
  source      = "./modules/sql"
}

module "cloudrun" {
  backend_paths       = var.backend_paths
  count               = (var.platform == "cloudrun") ? 1 : 0
  command_topic       = module.pubsub.command_topic
  content_key         = module.crypto.content_key
  datastore_namespace = var.datastore_namespace
  deployers           = var.deployers
  deployment_env      = var.deployment_env
  encryption_key      = module.crypto.encryption_key
  frontend            = var.frontend
  http_loglevel       = var.http_loglevel
  index_key           = module.crypto.index_key
  ingress             = var.ingress
  invokers            = var.invokers
  locations           = var.locations
  memory              = var.memory
  min_instances       = var.min_instances
  project             = local.services_project_id
  project_prefix      = var.project_prefix
  source              = "./modules/cloudrun"
  secrets             = module.secrets.secrets
  service_account     = google_service_account.default.name
  service_domain      = local.service_domain
  service_id          = var.service_id
  service_project     = google_project.service.project_id
  signing_key         = module.crypto.signing_key
  sql_databases       = [for spec in module.sql: spec.connection]
  storage_bucket      = (var.storage_bucket != null) ? module.storage[0].bucket_name : null
  subscribes          = var.subscribes
  variables           = var.variables

  depends_on = [
    google_project.service,
    google_project_service.required,
    module.crypto,
    module.pubsub,
    module.secrets,
    module.sql,
    module.storage
  ]
}

module "secrets" {
  source          = "./modules/secrets"
  locations       = var.secret_locations
  project         = google_project.service.project_id
  service_account = google_service_account.default.email
  secrets         = merge(
    local.secrets,
    (var.mount_service_account_key != true) ? {} : {
      GOOGLE_APPLICATION_CREDENTIALS = {
        name      = "GOOGLE_APPLICATION_CREDENTIALS",
        secret    = "google-application-credentials",
        initial   = base64decode(google_service_account_key.default[0].private_key),
        mount     = "service-account.json"
      }
    }
  )

  depends_on      = [
    google_service_account.default,
    google_service_account_key.default
  ]
}

# resource "google_kms_crypto_key" "keys" {
#   depends_on      = [google_kms_key_ring.default]
#   for_each        = {for spec in var.keys: spec.name => spec}
#   name            = each.value.name
#   key_ring        = google_kms_key_ring.default.id
#   purpose         = each.value.purpose

#   version_template {
#     algorithm         = each.value.algorithm
#     protection_level  = each.value.protection_level
#   }
# }

# # If the artifact registry is in a different project, then grant
# # permission to the Cloud Run Service Agent of this project
# # to pull images.
# resource "google_artifact_registry_repository_iam_member" "cloudrun" {
#   depends_on  = [google_cloud_run_service.default]
#   count       = (var.artifact_registry_project != null) ? 1 : 0
#   project     = var.artifact_registry_project
#   location    = var.artifact_registry_location
#   repository  = var.artifact_registry_name
#   role        = "roles/artifactregistry.reader"
#   member      = "serviceAccount:service-${google_project.service[0].number}@serverless-robot-prod.iam.gserviceaccount.com"
# }

# # Storage
module "datastore" {
  source              = "./modules/datastore"
  depends_on          = [google_project_service.required, google_service_account.default]
  count               = (var.datastore_location != null) ? 1 : 0
  datastore_location  = var.datastore_location
  project             = google_project.service.project_id
  service_account     = google_service_account.default.email
}

# # Public routing of the service. Can be a domain map or a load balancer.
# module "domain-map" {
#   depends_on      = [google_project_service.required]
#   count           = (var.with_domain_map) ? 1 : 0
#   source          = "./modules/domain-map"
#   dns_project     = var.dns_project
#   dns_zone        = var.dns_zone
#   locations       = var.locations
#   project         = local.project
#   services        = [
#     for spec in google_cloud_run_service.default:
#     {location = spec.location, name = spec.name, project = spec.project}
#   ]
#   service_domain  = local.service_domain
# }

module "loadbalancer" {
  depends_on      = [
    google_project_service.required,
    module.cloudrun
  ]
  accepted_hosts  = var.accepted_hosts
  backend_paths   = var.backend_paths
  count           = (var.loadbalancer) ? 1 : 0
  backend_id      = module.cloudrun[0].backend_id
  frontend        = var.frontend
  source          = "./modules/loadbalancer"
  dns_project     = var.dns_zone_project
  dns_zone        = var.dns_zone_name
  domains         = var.domains
  locations       = var.locations
  project         = local.services_project_id
  service_domain  = local.service_domain
  service_id      = var.service_id
  suffix          = random_string.project_suffix.result
}

#module "logging" {
#  count           = (var.default_log_bucket != null && var.default_log_location != null) ? 1 : 0
#  source          = "./modules/logging"
#  destination     = "logging.googleapis.com/projects/${var.project}/locations/${var.default_log_location}/buckets/${var.default_log_bucket}"
#  project         = var.project
#  service_project = local.services_project_id
#}

module "pubsub" {
  source          = "./modules/pubsub"
  audience        = "https://${local.service_domain}/.well-known/aorta"
  endpoint        = "https://${local.service_domain}/.well-known/aorta"
  events          = var.events
  project_prefix  = var.project_prefix
  publishes       = var.publishes
  service_account = google_service_account.default.email
  service_id      = var.service_id
  service_project = local.services_project_id
  subscribes      = var.subscribes
}

resource "google_pubsub_topic" "keepalive" {
  project = local.services_project_id
  name    = "keepalive.${var.service_id}"
}

resource "google_cloud_scheduler_job" "keepalive" {
  depends_on        = [google_project_service.required]
  for_each          = toset((var.ping_schedule == null) ? [] : var.ping_locations)
  project           = local.services_project_id
  name              = "${var.service_id}-${random_string.project_suffix.result}-keepalive"
  schedule          = var.ping_schedule
  region            = "europe-west3"

  pubsub_target {
    topic_name = google_pubsub_topic.keepalive.id
    data       = base64encode(
      jsonencode({
        apiVersion  = "v1"
        kind        = "Ping"
        type        = "unimatrixone.io/command"
        spec        = {}
      })
    )
  }
}

# output "docker_repository" {
#   description = "The Docker repository URL for the Cloud Run image."
#   value       = "${var.artifact_registry_location}-docker.pkg.dev/${var.artifact_registry_project}/${var.artifact_registry_name}/${var.service_id}"
# }
resource "random_string" "beats" {
  count     = length(var.beats)
  length    = 6
  special   = false
  upper     = false
}

module "beats" {
  count         = length(var.beats)
  depends_on    = [module.pubsub]
  source        = "./modules/beats"
  project       = local.services_project_id
  command_name  = var.beats[count.index].command_name
  command_topic = module.pubsub.command_topic
  name          = "beat-${random_string.beats[count.index].result}"
  params        = var.beats[count.index].params
  schedule      = var.beats[count.index].schedule
}
