# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "master" { type=string }
variable "name" { type=string }
variable "replicas" { type=list(string) }
variable "project" { type=string }

locals {
  database = "cluster-${random_string.cluster.result}"
  username = "user-${random_string.user.result}"
  password = random_string.password.result
}

data "google_sql_database_instance" "master" {
  project = var.project
  name    = var.master
}

resource "random_string" "cluster" {
  length    = 6
  special   = false
  upper     = false
}

resource "random_string" "user" {
  length    = 6
  special   = false
  upper     = false
}

resource "random_string" "password" {
  length    = 32
  special   = false
  upper     = false
}

resource "google_sql_database" "cluster" {
  depends_on  = [data.google_sql_database_instance.master]
  project     = var.project
  name        = local.database
  instance    = data.google_sql_database_instance.master.name
}

resource "google_sql_user" "user" {
  depends_on  = [data.google_sql_database_instance.master]
  project     = var.project
  name        = local.username
  instance    = data.google_sql_database_instance.master.name
  password    = local.password
}

output "connection" {
  value = {
    connection=var.name
    engine="postgresql"
    host=data.google_sql_database_instance.master.private_ip_address
    port=5432
    name=local.database
    user=local.username
    password=local.password
  }
}