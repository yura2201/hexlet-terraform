// Configure the Yandex.Cloud provider
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    datadog = {
      source = "DataDog/datadog"
    }
  }
  required_version = ">= 0.13"
}

variable "token" {
  type      = string
  sensitive = true
}
variable "cloud_id" {}
variable "folder_id" {}

provider "yandex" {
  token = var.token
  #  service_account_key_file = "path_to_service_account_key_file"
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}

# https://cloud.yandex.com/ru/docs/compute/concepts/disk
resource "yandex_compute_disk" "boot-disk-1" {
  name = "disk-1"
  type = "network-hdd"
  zone = "ru-central1-a"
  # GiB
  size = "8"
  # yc compute image list --folder-id standard-images
  image_id = "fd8bkgba66kkf9eenpkb"
}

resource "yandex_compute_disk" "boot-disk-2" {
  name = "disk-2"
  type = "network-hdd"
  zone = "ru-central1-a"
  # GiB
  size = "8"
  # yc compute image list --folder-id standard-images
  image_id = "fd8bkgba66kkf9eenpkb"
}

resource "yandex_vpc_network" "network-1" {
  name = "yandex-student-network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "yandex-student-subnet-1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_compute_instance" "web-1" {
  name = "yandex-student"
  # https://cloud.yandex.ru/ru/docs/compute/concepts/vm-platforms
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    # Гарантированная доля vCPU, %
    core_fraction = 5
    cores         = 2
    # GiB
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  # прерываемая
  scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id/yandex/cloud/id_student_ed25519.pub")}"
  }
}

resource "yandex_compute_instance" "web-2" {
  name = "yandex-student-2"
  # https://cloud.yandex.ru/ru/docs/compute/concepts/vm-platforms
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    # Гарантированная доля vCPU, %
    core_fraction = 5
    cores         = 2
    # GiB
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  # прерываемая
  scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id/yandex/cloud/id_student_2_ed25519.pub")}"
  }
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.web-1.network_interface.0.ip_address
}

output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.web-2.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.web-1.network_interface.0.nat_ip_address
}

output "external_ip_address_vm_2" {
  value = yandex_compute_instance.web-2.network_interface.0.nat_ip_address
}

###################
# Configure the Datadog provider
variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.eu/"
}