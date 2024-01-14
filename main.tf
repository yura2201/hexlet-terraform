// Configure the Yandex.Cloud provider
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

variable "token" {}
variable "cloud_id" {}
variable "folder_id" {}

provider "yandex" {
  token                    = var.token
#  service_account_key_file = "path_to_service_account_key_file"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru-central1-a"
}




// Create a new instance
#resource "yandex_compute_instance" "default" {
#  ...
#}