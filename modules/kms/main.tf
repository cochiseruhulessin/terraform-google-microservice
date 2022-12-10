# Copyright (C) 2022 Cochise Ruhulessin
#
# All rights reserved. No warranty, explicit or implicit, provided. In
# no event shall the author(s) be liable for any claim or damages.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
variable "encryption_key_version" { default = 1 }
variable "location" { type = string }
variable "name" { type = string }
variable "project" { type = string }
variable "service_account" { type = string}
variable "signing_key_version" { default = 1 }


# By default, the service has a signing keypair that it
# uses to identify itself, and an asymmetric encryption
# key to encrypt data.
resource "google_kms_key_ring" "default" {
  project    = var.project
  name       = var.name
  location   = var.location
}

resource "google_kms_key_ring_iam_binding" "viewer" {
  key_ring_id = google_kms_key_ring.default.id
  role        = "roles/cloudkms.viewer"
  members     = ["serviceAccount:${var.service_account}"]
}

resource "google_kms_key_ring_iam_binding" "operator" {
  key_ring_id = google_kms_key_ring.default.id
  role        = "roles/cloudkms.cryptoOperator"
  members     = ["serviceAccount:${var.service_account}"]
}

resource "google_kms_crypto_key" "sig" {
  depends_on      = [google_kms_key_ring.default]
  name            = "sig"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ASYMMETRIC_SIGN"

  version_template {
    algorithm         = "EC_SIGN_P384_SHA384"
    protection_level  = "HSM"
  }
}

resource "google_kms_crypto_key" "enc" {
  depends_on      = [google_kms_key_ring.default]
  name            = "enc"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ASYMMETRIC_DECRYPT"

  version_template {
    algorithm         = "RSA_DECRYPT_OAEP_3072_SHA256"
    protection_level  = "HSM"
  }
}

resource "google_kms_crypto_key" "pii" {
  depends_on      = [google_kms_key_ring.default]
  name            = "pii"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm         = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level  = "HSM"
  }
}

resource "google_kms_crypto_key" "idx" {
  depends_on      = [google_kms_key_ring.default]
  name            = "idx"
  key_ring        = google_kms_key_ring.default.id
  purpose         = "MAC"

  version_template {
    algorithm         = "HMAC_SHA256"
    protection_level  = "HSM"
  }
}

output "content_key" {
  value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.pii.id}?version=1"
}

output "encryption_key" {
  value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.enc.id}?version=${var.encryption_key_version}"
}

output "index_key" {
  value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.idx.id}?version=1"
}

output "signing_key" {
  value = "google://cloudkms.googleapis.com/${google_kms_crypto_key.sig.id}?version=${var.signing_key_version}"
}