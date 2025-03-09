# Network infrastructure for the Yandex Application Load Balancer
#
# RU: https://yandex.cloud/ru/docs/tutorials/security/migration-from-nlb-to-alb/nlb-with-target-resource-k8s/terraform
# EN: https://yandex.cloud/en/docs/tutorials/security/migration-from-nlb-to-alb/nlb-with-target-resource-k8s/terraform

# Specify the following settings:
locals {
  # The following settings are to be specified by the user. Change them as you wish.
  domain_name = "" # Domain name of your service
  network_id  = "" # ID of the network where the VMs are located
  certificate = "" # Path to a file with a certificate
  private_key = "" # Path to a file with a private key

  # The following settings are predefined. Change them only if necessary.
  network_name        = "alb-network"        # Network name
  subnet_a_name       = "alb-subnet-a"       # Subnet-a name
  subnet_b_name       = "alb-subnet-b"       # Subnet-b name
  subnet_d_name       = "alb-subnet-d"       # Subnet-d name
  security_group_name = "alb-security-group" # Security group name
  static_address_name = "alb-static-address" # Static address name
  sws_profile_name    = "sws-profile"        # Security profile name
  cert_name           = "user-certificate"   # User certificate name
}

# Network infrastructure

resource "yandex_vpc_subnet" "alb-subnet-a" {
  description    = "Subnet-a in the ru-central1-a availability zone for Application Load Balancer network"
  name           = local.subnet_a_name
  zone           = "ru-central1-a"
  network_id     = local.network_id
  v4_cidr_blocks = ["10.51.0.0/16"]
}

resource "yandex_vpc_subnet" "alb-subnet-b" {
  description    = "Subnet-b in the ru-central1-b availability zone for Application Load Balancer network"
  name           = local.subnet_b_name
  zone           = "ru-central1-b"
  network_id     = local.network_id
  v4_cidr_blocks = ["10.52.0.0/16"]
}

resource "yandex_vpc_subnet" "alb-subnet-d" {
  description    = "Subnet-d in the ru-central1-d availability zone for Application Load Balancer network"
  name           = local.subnet_d_name
  zone           = "ru-central1-d"
  network_id     = local.network_id
  v4_cidr_blocks = ["10.53.0.0/16"]
}

resource "yandex_vpc_security_group" "alb-security-group" {
  description = "Security group for the Application Load Balancer"
  name        = local.security_group_name
  network_id  = local.network_id

  ingress {
    description    = "Ext-http"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    description    = "Ext-https"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    description       = "Healthchecks"
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }

  egress {
    description    = "Allow all outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_address" "static-address" {
  description = "Static public IP address for the Application Load Balancer"
  name        = "alb-static-address"
  external_ipv4_address {
    zone_id                  = "ru-central1-a"
    ddos_protection_provider = "qrator"
  }
}

# Infrastructure for the Certificate Manager

resource "yandex_cm_certificate" "user-certificate" {
  description = "Custom TLS certificate"
  name        = local.cert_name

  self_managed {
    certificate = file(local.certificate)
    private_key = file(local.private_key)
  }
}

# Infrastructure for the Smart Web Security

resource "yandex_sws_security_profile" "sws-profile" {
  description    = "Security profile for the Application Load Balancer"
  name           = local.sws_profile_name
  default_action = "ALLOW"

  security_rule {
    description = "Smart protection is enabled in full mode"
    name        = "smart-protection-rule"
    dry_run     = true
    priority    = 999900
    smart_protection {
      mode = "FULL"
    }
  }
}
