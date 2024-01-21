// Configure the Yandex.Cloud provider
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.47.0"
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
variable "cloud_id" {
  type      = string
  sensitive = true
}
variable "folder_id" {
  type      = string
  sensitive = true
}

variable "yc_main_zone" {}
variable "os_image" {}

provider "yandex" {
  token = var.token
  #  service_account_key_file = "path_to_service_account_key_file"
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.yc_main_zone
}

variable "yc_account_id" {
  type      = string
  sensitive = true
}

variable "yc_zones" {
  type = list(string)
}

variable "yc_user" {
  type      = string
  sensitive = true
}

resource "yandex_compute_instance_group" "yandex-student-instance-group" {
  name               = "nlb-vm-group"
  folder_id          = var.folder_id
  service_account_id = var.yc_account_id

  instance_template {
    platform_id = "standard-v1"

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = var.os_image
        type     = "network-hdd"
        size     = 8
      }
    }

    network_interface {
      network_id = yandex_vpc_network.network-1.id
      subnet_ids = [yandex_vpc_subnet.subnet-1.id, yandex_vpc_subnet.subnet-2.id]
      nat        = true
    }

    resources {
      core_fraction = 5
      cores         = 2
      memory        = 2
    }

    # прерываемая
    scheduling_policy {
      preemptible = true
    }

    metadata = {
      user-data = "#cloud-config\nusers:\n  - name: ${var.yc_user}\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${file("~/.ssh/id/yandex/cloud/id_student_ed25519.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = var.yc_zones
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  load_balancer {
    target_group_name = "yandex-student-target-group"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "yandex-student-network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "yandex-student-subnet-1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "yandex-student-subnet-2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.2.0/24"]
}

resource "yandex_lb_network_load_balancer" "balancer" {
  name = "yandex-student-load-balancer"
  listener {
    name        = "yandex-student-listener"
    port        = 80
    target_port = 80
  }
  attached_target_group {
    target_group_id = yandex_compute_instance_group.yandex-student-instance-group.load_balancer.0.target_group_id
    healthcheck {
      name                = "health-check-1"
      unhealthy_threshold = 5
      healthy_threshold   = 5
      http_options {
        port = 80
      }
    }
  }
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