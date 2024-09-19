variable "account_file" {
  type    = string
  default = "${env("GOOGLE_APPLICATION_CREDENTIALS")}"
}

variable "projectId" { default = "dev-project" }
variable "zone" { default = "europe-west1-d" }
variable "instance_name" { default = "dataproc-custom-image-instance" }
variable "network" { default = "base-network" }
variable "image_name" { default = "dataproc-custom-spark-rlc-image-1-5-56-us" }
variable "image_storage_locations" {
  type    = list(string)
  default = ["us"]
}
variable "image_family" { default = "dataproc-custom-image-1-5-56" }
variable "image_desc" { default = "custom image for dataproc cluster" }
variable "subnetwork" { default = "dev-subnet" }
variable "set_true" {
  type    = bool
  default = true
}
variable "set_false" {
  type    = bool
  default = false
}
variable "sa_email" { default = "ci-cd@dev-project.iam.gserviceaccount.com" }
variable "source_image" { default = "dataproc-1-5-deb10-20220125-170200-rc01" }
variable "source_image_project_id" {
  type    = list(string)
  default = ["cloud-dataproc"]
}
variable "disk_name" { default = "dataproc-1-5-56-image-install" }
variable "disk_size" { default = 50 }
variable "tags" {
  type    = list(string)
  default = ["dev-allow-ssh"]
}
variable "ssh_username" { default = "kiran_peddineni_com" }
variable "ssh_key_file_path" { default = "/home/kiran_peddineni_com/.ssh/google_compute_engine" }

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")

  image_labels = {
    goog-dataproc-version = "1-5-56-debian10"
    componenet            = "dataproc-custom-spark-image"
    environment           = "dev"
    owner                 = "dma"
  }
}

source "googlecompute" "dataproc-custom-spark-image" {
  project_id              = var.projectId
  zone                    = var.zone
  account_file            = "${var.account_file}"
  instance_name           = "${var.instance_name}-${local.timestamp}"
  image_name              = var.image_name
  image_storage_locations = var.image_storage_locations
  image_family            = var.image_family
  image_description       = var.image_desc
  network                 = var.network
  subnetwork              = var.subnetwork
  omit_external_ip        = var.set_true
  service_account_email   = var.sa_email
  source_image            = var.source_image
  source_image_project_id = var.source_image_project_id
  disk_name               = var.disk_name
  disk_size               = var.disk_size
  tags                    = var.tags
  ssh_username            = var.ssh_username
  use_os_login            = var.set_true
  use_iap                 = var.set_true
  use_internal_ip         = var.set_true
  ssh_private_key_file    = var.ssh_key_file_path

  image_labels = local.image_labels
}

build {
  sources = ["source.googlecompute.dataproc-custom-image"]

  provisioner "file" {
    source = "scripts/requirements.txt"
    destination = "/tmp/requirements.txt"
  }

  provisioner "shell" {
    script = "./scripts/custom-dataproc-spark-image-script.sh"
  }
}
