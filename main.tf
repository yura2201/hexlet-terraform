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
variable "cloud_id" {
  type      = string
  sensitive = true
}
variable "folder_id" {
  type      = string
  sensitive = true
}

variable "yc_zone" {}
variable "os_image" {}

variable "yc_user" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type      = string
  sensitive = true
}

variable "db_user" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

provider "yandex" {
  token = var.token
  #  service_account_key_file = "path_to_service_account_key_file"
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.yc_zone
}

# https://cloud.yandex.com/ru/docs/compute/concepts/disk
resource "yandex_compute_disk" "boot-disk-1" {
  name = "disk-1"
  type = "network-hdd"
  zone = var.yc_zone
  # GiB
  size = "30"
  # yc compute image list --folder-id standard-images
  image_id = var.os_image
}

resource "yandex_compute_disk" "boot-disk-2" {
  name = "disk-2"
  type = "network-hdd"
  zone = var.yc_zone
  # GiB
  size = "30"
  # yc compute image list --folder-id standard-images
  image_id = var.os_image
}

resource "yandex_vpc_network" "network-1" {
  name = "yandex-student-network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "yandex-student-subnet-1"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_compute_instance" "web-1" {
  name = "yandex-student"
  # https://cloud.yandex.ru/ru/docs/compute/concepts/vm-platforms
  platform_id = "standard-v1"
  zone        = var.yc_zone

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
    user-data = "#cloud-config\nusers:\n  - name: ${var.yc_user}\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${file("~/.ssh/id/yandex/cloud/id_student.pub")}"
  }

  connection {
    type        = "ssh"
    user        = var.yc_user
    private_key = file("~/.ssh/id/yandex/cloud/id_student")
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      <<EOT
sudo docker run -d -p 0.0.0.0:80:3000 \
  -e DB_TYPE=postgres \
  -e DB_NAME=${var.db_name} \
  -e DB_HOST=${yandex_mdb_postgresql_cluster.pg-cluster.host.0.fqdn} \
  -e DB_PORT=6432 \
  -e DB_USER=${var.db_user} \
  -e DB_PASS=${var.db_password} \
  ghcr.io/requarks/wiki:2.5
EOT
    ]
  }
#  provisioner "remote-exec" {
#    inline = [
#      <<EOT
#echo test
#EOT
#    ]
#  }

  depends_on = [yandex_mdb_postgresql_cluster.pg-cluster]
}

resource "yandex_compute_instance" "web-2" {
  name = "yandex-student-2"
  # https://cloud.yandex.ru/ru/docs/compute/concepts/vm-platforms
  platform_id = "standard-v1"
  zone        = var.yc_zone

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
    user-data = "#cloud-config\nusers:\n  - name: ${var.yc_user}\n    groups: sudo\n    shell: /bin/bash\n    sudo: 'ALL=(ALL) NOPASSWD:ALL'\n    ssh-authorized-keys:\n      - ${file("~/.ssh/id/yandex/cloud/id_student_2.pub")}"
  }

  connection {
    type        = "ssh"
    user        = var.yc_user
    private_key = file("~/.ssh/id/yandex/cloud/id_student_2")
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      <<EOT
sudo docker run -d -p 0.0.0.0:80:3000 \
  -e DB_TYPE=postgres \
  -e DB_NAME=${var.db_name} \
  -e DB_HOST=${yandex_mdb_postgresql_cluster.pg-cluster.host.0.fqdn} \
  -e DB_PORT=6432 \
  -e DB_USER=${var.db_user} \
  -e DB_PASS=${var.db_password} \
  ghcr.io/requarks/wiki:2.5
EOT
    ]
  }
#  provisioner "remote-exec" {
#    inline = [
#      <<EOT
#echo test
#EOT
#    ]
#  }

  depends_on = [yandex_mdb_postgresql_cluster.pg-cluster]
}

resource "yandex_lb_target_group" "target-group" {
  name = "yandex-student-target-group"

  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.web-1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address   = yandex_compute_instance.web-2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "balancer" {
  name = "yandex-student-load-balancer"
  listener {
    name        = "yandex-student-listener"
    port        = 80
    target_port = 80
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.target-group.id
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

variable "yc_postgresql_version" {
  type = number
}

resource "yandex_mdb_postgresql_cluster" "pg-cluster" {

  name        = "student-pg-cluster"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.network-1.id

  config {
    version = var.yc_postgresql_version
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 15
    }
    postgresql_config = {
      max_connections = 100
    }
  }

  maintenance_window {
    type = "WEEKLY"
    day  = "SAT"
    hour = 12
  }

  host {
    zone      = var.yc_zone
    subnet_id = yandex_vpc_subnet.subnet-1.id
  }

  depends_on = [yandex_vpc_network.network-1, yandex_vpc_subnet.subnet-1]
}

resource "yandex_mdb_postgresql_user" "db-user" {
  cluster_id = yandex_mdb_postgresql_cluster.pg-cluster.id
  name       = var.db_user
  password   = var.db_password
  depends_on = [yandex_mdb_postgresql_cluster.pg-cluster]
}

resource "yandex_mdb_postgresql_database" "db" {
  cluster_id = yandex_mdb_postgresql_cluster.pg-cluster.id
  name       = var.db_name
  owner      = yandex_mdb_postgresql_user.db-user.name
  lc_collate = "en_US.UTF-8"
  lc_type    = "en_US.UTF-8"
  depends_on = [yandex_mdb_postgresql_cluster.pg-cluster, yandex_mdb_postgresql_user.db-user]
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