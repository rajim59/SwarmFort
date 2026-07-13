terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      skip_shutdown_and_force_delete = true
    }
  }
}

resource "azurerm_resource_group" "swarm_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Development"
    Project     = "DockerSwarm"
  }
}

resource "azurerm_virtual_network" "swarm_vnet" {
  name                = "swarm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.swarm_rg.location
  resource_group_name = azurerm_resource_group.swarm_rg.name
}

resource "azurerm_subnet" "swarm_subnet" {
  name                 = "swarm-subnet"
  resource_group_name  = azurerm_resource_group.swarm_rg.name
  virtual_network_name = azurerm_virtual_network.swarm_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "swarm_nsg" {
  name                = "swarm-nsg"
  location            = azurerm_resource_group.swarm_rg.location
  resource_group_name = azurerm_resource_group.swarm_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGrafana"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPrometheus"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowFluentdForward"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "24224"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSwarmMgmt"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2377"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSwarmNodeComm"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "7946"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSwarmOverlay"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4789"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "manager_pip" {
  name                = "manager-pip"
  location            = azurerm_resource_group.swarm_rg.location
  resource_group_name = azurerm_resource_group.swarm_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "manager_nic" {
  name                = "manager-nic"
  location            = azurerm_resource_group.swarm_rg.location
  resource_group_name = azurerm_resource_group.swarm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.manager_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "manager_assoc" {
  network_interface_id      = azurerm_network_interface.manager_nic.id
  network_security_group_id = azurerm_network_security_group.swarm_nsg.id
}

resource "azurerm_network_interface" "worker_nic" {
  count               = 2
  name                = "worker-${count.index + 1}-nic"
  location            = azurerm_resource_group.swarm_rg.location
  resource_group_name = azurerm_resource_group.swarm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${count.index + 5}"
  }
}

resource "azurerm_network_interface_security_group_association" "worker_assoc" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.worker_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.swarm_nsg.id
}

locals {
  docker_install_and_harden = <<EOF
#!/bin/bash
# SwarmFort - Swarm Compatible Hardened Docker Installation Script
exec > /var/log/docker-setup-custom.log 2>&1
set -x

export DEBIAN_FRONTEND=noninteractive

echo "⏳ Waiting for Ubuntu background updates to release apt lock..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do sleep 2; done
while fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do sleep 2; done

echo "🧹 Removing old/broken Docker versions..."
apt-get remove -y docker docker-engine docker.io containerd runc || true

echo "📦 Installing prerequisites..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release apparmor apparmor-utils

echo "🔑 Setting up Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

echo "🚀 Installing Docker Engine..."
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "👤 Adding admin user to docker group..."
usermod -aG docker ${var.admin_username}

echo "⚙️ Configuring daemon.json for Swarm compatibility..."
mkdir -p /etc/docker
cat <<JSON > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": false,
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "userland-proxy": false
}
JSON

echo "🔄 Starting Docker Service..."
systemctl daemon-reload
systemctl enable docker
systemctl restart docker

echo "🧠 Tuning Kernel..."
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

echo "✅ Docker setup completed successfully!"
EOF
}
resource "azurerm_linux_virtual_machine" "manager" {
  name                = "swarm-manager-1"
  resource_group_name = azurerm_resource_group.swarm_rg.name
  location            = azurerm_resource_group.swarm_rg.location
  size                = var.manager_vm_size
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  network_interface_ids = [azurerm_network_interface.manager_nic.id]
  custom_data           = base64encode(local.docker_install_and_harden)

  depends_on = [azurerm_network_interface_security_group_association.manager_assoc]
}

resource "azurerm_linux_virtual_machine" "workers" {
  count               = 2
  name                = "swarm-worker-${count.index + 1}"
  resource_group_name = azurerm_resource_group.swarm_rg.name
  location            = azurerm_resource_group.swarm_rg.location
  size                = var.worker_vm_size
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  network_interface_ids = [azurerm_network_interface.worker_nic[count.index].id]
  custom_data           = base64encode(local.docker_install_and_harden)

  depends_on = [azurerm_network_interface_security_group_association.worker_assoc]
}

output "manager_public_ip" {
  value = azurerm_public_ip.manager_pip.ip_address
}

output "worker_private_ips" {
  value = azurerm_linux_virtual_machine.workers[*].private_ip_address
}