terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.5.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "c0d63f1e-890a-409d-b009-fead0d47b556"
  features {}
}

resource "azurerm_resource_group" "example_rg" {
  name     = "example-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "example_vnet" {
  name                = "example-vnet"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example_subnet" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example_rg.name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "example_lb_ip" {
  name                = "example-lb-ip"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "example_lb" {
  name                = "example-lb"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.example_lb_ip.id
  }
}

resource "azurerm_network_security_group" "example_nsg" {
  name                = "example-nsg"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow_http"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_network_security_group.example_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.example_nsg.name
}

resource "azurerm_lb_backend_address_pool" "example_lb_backend_pool" {
  name            = "example-backend-pool"
  loadbalancer_id = azurerm_lb.example_lb.id
}

resource "azurerm_lb_rule" "example_lb_rule" {
  name                                    = "example-lb-rule"
  loadbalancer_id                         = azurerm_lb.example_lb.id
  frontend_ip_configuration_name           = azurerm_lb.example_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids                 = [azurerm_lb_backend_address_pool.example_lb_backend_pool.id]
  protocol                                = "Tcp"
  frontend_port                            = 80
  backend_port                             = 80
  idle_timeout_in_minutes                 = 4
  enable_floating_ip                      = false
}

resource "azurerm_linux_virtual_machine_scale_set" "example_vmss" {
  name                = "example-vmss"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
  sku                 = "Standard_DS1_v2"
  instances           = 2

  admin_username      = "adminuser"
  admin_ssh_key {
    username   = "adminuser"
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFZJqqa8lswSmI5OM+ZU19YdVB3g0eX0MuPiVL+E5A/W Gabriel@LAPTOP-Q1SMBO4K"
  }

  network_interface {
    name    = "example-nic"
    primary = true

    ip_configuration {
      name                          = "internal"
      subnet_id                     = azurerm_subnet.example_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.example_lb_backend_pool.id]
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
}
