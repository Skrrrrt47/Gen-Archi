provider "azurerm" {
  features {}
  subscription_id = "<VOTRE_SUBSCRIPTION_ID>"
  client_id       = "<VOTRE_CLIENT_ID>"
  client_secret   = "<VOTRE_CLIENT_SECRET>"
  tenant_id       = "<VOTRE_TENANT_ID>"
}

resource "azurerm_resource_group" "platform_rg" {
  name     = "platform2-rg"
  location = "West Europe"
}

# Réseau Virtuel et Sous-réseaux
resource "azurerm_virtual_network" "main_vnet" {
  name                = "platform2-vnet"
  location            = azurerm_resource_group.platform_rg.location
  resource_group_name = azurerm_resource_group.platform_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "nosql_subnet" {
  name                 = "nosql-subnet"
  resource_group_name  = azurerm_resource_group.platform_rg.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Machine Virtuelle pour NoSQL
resource "azurerm_linux_virtual_machine" "nosql_vm" {
  name                = "nosql-vm"
  resource_group_name = azurerm_resource_group.platform_rg.name
  location            = azurerm_resource_group.platform_rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "P@ssword123!"

  network_interface_ids = [azurerm_network_interface.nosql_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "nosql_nic" {
  name                = "nosql-nic"
  resource_group_name = azurerm_resource_group.platform_rg.name
  location            = azurerm_resource_group.platform_rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nosql_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Machine Virtuelle NoSQL dans une autre zone de disponibilité (AZ-2)
resource "azurerm_linux_virtual_machine" "nosql_vm_az2" {
  name                = "nosql-vm-az2"
  resource_group_name = azurerm_resource_group.platform_rg.name
  location            = azurerm_resource_group.platform_rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "P@ssword123!"

  network_interface_ids = [azurerm_network_interface.nosql_nic_az2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "nosql_nic_az2" {
  name                = "nosql-nic-az2"
  resource_group_name = azurerm_resource_group.platform_rg.name
  location            = azurerm_resource_group.platform_rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nosql_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine Scale Set (VMSS) Spot Instances
resource "azurerm_linux_virtual_machine_scale_set" "spot_vmss" {
  name                = "spot-vmss"
  resource_group_name = azurerm_resource_group.platform_rg.name
  location            = azurerm_resource_group.platform_rg.location
  sku                 = "Standard_DS1_v2"
  instances           = 2

  admin_username      = "adminuser"
  admin_password      = "P@ssword123!"

  network_interface {
    name = "spot-nic"

    ip_configuration {
      name                          = "internal"
      subnet_id                     = azurerm_subnet.nosql_subnet.id
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  priority        = "Spot"
  eviction_policy = "Deallocate"
  max_bid_price   = -1  # Valeur maximale pour spot

  # Utilisation d'une extension pour cloner un dépôt Git et lancer l'application
  extension {
    name                 = "CustomScriptForLinux"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"

    settings = <<SETTINGS
      {
        "fileUris": [],
        "commandToExecute": "bash -c 'git clone <URL_DU_DEPOT_GIT> /path/vers/le/dossier; cd /path/vers/le/dossier; npm install; npm start'"
      }
    SETTINGS
  }
}

# Load Balancer
resource "azurerm_lb" "platform_lb" {
  name                = "platform-lb"
  location            = azurerm_resource_group.platform_rg.location
  resource_group_name = azurerm_resource_group.platform_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.platform_lb_public_ip.id
  }
}

resource "azurerm_public_ip" "platform_lb_public_ip" {
  name                = "platform-lb-pip"
  location            = azurerm_resource_group.platform_rg.location
  resource_group_name = azurerm_resource_group.platform_rg.name
  allocation_method   = "Static"
}

# Groupes de Sécurité pour les NoSQL et VMSS
resource "azurerm_network_security_group" "nsg_nosql" {
  name                = "nsg-nosql"
  location            = azurerm_resource_group.platform_rg.location
  resource_group_name = azurerm_resource_group.platform_rg.name
}

resource "azurerm_network_security_rule" "allow_inbound" {
  name                        = "allow_inbound_ssh"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.nsg_nosql.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg_nosql.name
}

resource "azurerm_network_interface_security_group_association" "nosql_nic_assoc" {
  network_interface_id      = azurerm_network_interface.nosql_nic.id
  network_security_group_id = azurerm_network_security_group.nsg_nosql.id
}

resource "azurerm_network_interface_security_group_association" "nosql_nic_az2_assoc" {
  network_interface_id      = azurerm_network_interface.nosql_nic_az2.id
  network_security_group_id = azurerm_network_security_group.nsg_nosql.id
}