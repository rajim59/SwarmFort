terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "swarm_rg" {
  name     = "swarmfort-resources-v3"
  location = "malaysiawest"

  tags = {
    Environment = "Development"
    Project     = "DockerSwarm"
  }
}

# Virtual Network
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

# NSG with required Swarm ports
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
    source_address_prefix      = "*"
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

  # Swarm management port (internal only)
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

  # Swarm node communication
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

  # Overlay network (VXLAN)
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

# ---------- Manager (public IP) ----------
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
    private_ip_address            = "10.0.1.4"    # <-- যোগ করা লাইন
    public_ip_address_id          = azurerm_public_ip.manager_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "manager_assoc" {
  network_interface_id      = azurerm_network_interface.manager_nic.id
  network_security_group_id = azurerm_network_security_group.swarm_nsg.id
}

# ---------- Workers (no public IP, now with static private IPs) ----------
resource "azurerm_network_interface" "worker_nic" {
  count               = 2
  name                = "worker-${count.index + 1}-nic"
  location            = azurerm_resource_group.swarm_rg.location
  resource_group_name = azurerm_resource_group.swarm_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.swarm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${count.index + 5}"   # .5 ও .6 হবে
    # No public IP
  }
}

resource "azurerm_network_interface_security_group_association" "worker_assoc" {
  count                     = 2
  network_interface_id      = azurerm_network_interface.worker_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.swarm_nsg.id
}

# Cloud-init script: install Docker and prepare user
locals {
  docker_install_script = <<-EOF
    #!/bin/bash
    set -e
    # Update and install Docker
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker azureuser
    # Enable Docker on boot
    sudo systemctl enable docker
    sudo systemctl start docker
    # Basic tuning
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
  EOF
}

# ---------- VMs ----------
resource "azurerm_linux_virtual_machine" "manager" {
  name                = "swarm-manager-1"
  resource_group_name = azurerm_resource_group.swarm_rg.name
  location            = azurerm_resource_group.swarm_rg.location
  size                = "Standard_B2ats_v2"     # 2 vCPU, 4 GB RAM
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  network_interface_ids = [azurerm_network_interface.manager_nic.id]
  custom_data           = base64encode(local.docker_install_script)

  depends_on = [azurerm_network_interface_security_group_association.manager_assoc]
}

resource "azurerm_linux_virtual_machine" "workers" {
  count               = 2
  name                = "swarm-worker-${count.index + 1}"
  resource_group_name = azurerm_resource_group.swarm_rg.name
  location            = azurerm_resource_group.swarm_rg.location
  size                = "Standard_B2ats_v2"
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  network_interface_ids = [azurerm_network_interface.worker_nic[count.index].id]
  custom_data           = base64encode(local.docker_install_script)

  depends_on = [azurerm_network_interface_security_group_association.worker_assoc]   # ✅ fixed line
}

# Outputs
output "manager_public_ip" {
  value       = azurerm_public_ip.manager_pip.ip_address
  description = "Public IP of the Swarm manager"
}

output "worker_private_ips" {
  value       = azurerm_linux_virtual_machine.workers[*].private_ip_address
  description = "Private IPs of worker nodes"
}