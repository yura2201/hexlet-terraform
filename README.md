# hexlet-terraform
Демонстрация возможностей [Terraform](https://www.terraform.io/) в реализации концепции "**Инфраструктура как код**"/"**Infrastructure as code**"(IaC) 

В проекте используется инфраструктура [Yandex Cloud](https://cloud.yandex.com/)

[Документация](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs)

[Зеркало документации](https://terraform-provider.yandexcloud.net/) в Yandex Cloud

[User Guide по Terraform](https://cloud.yandex.ru/ru/docs/tutorials/infrastructure-management/terraform-quickstart#linux-macos_1) в Yandex Cloud
## Подготовка
### Создать зеркало для провайдера
Создать файл конфигурации

`nano ~/.terraformrc`

Добавить блок:

```
provider_installation {
    network_mirror {
        url = "https://terraform-mirror.yandexcloud.net/"
        include = ["registry.terraform.io/*/*"]
    }
    direct {
        exclude = ["registry.terraform.io/*/*"]
    }
}
```