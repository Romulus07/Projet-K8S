# Déclaration de la ressource random_pet
resource "random_pet" "rg_name" {
  prefix = "${var.resource_group_name_prefix}"
}

# Déclaration de la ressource azurerm_resource_group
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Création du réseau virtuel
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "Vnet-k8s"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Création du sous-réseau
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "k8s-ySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}


# Création des adresses IP publiques
resource "azurerm_public_ip" "my_terraform_public_ip" {
  count = 2
  name                = "k8s-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Création du groupe de sécurité réseau et de la règle SSH
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Création de l'interface réseau
resource "azurerm_network_interface" "my_terraform_nic" {
  count = 2
  name                = "k8s-NIC${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip[count.index].id
  }
}

# Association du groupe de sécurité au réseau d'interface
resource "azurerm_network_interface_security_group_association" "example" {
  count = 2
  network_interface_id      = azurerm_network_interface.my_terraform_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Génération de texte aléatoire pour les noms de compte de stockage uniques
resource "random_id" "storage_id" {
  count = 2
  byte_length = 8
}

# Création des comptes de stockage pour les diagnostics de démarrage
resource "azurerm_storage_account" "my_storage_account" {
  count = 2
  name                     = "diag${element(random_id.storage_id.*.hex, count.index)}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Création de la machine virtuelle
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  count = 2
  name                  = "k8s-${count.index}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic[count.index].id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "k8s"
  admin_username = var.username

  tags = {
    Name = "k8s ${count.index}"
  }

  admin_ssh_key {
    username   = var.username
    public_key = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account[count.index].primary_blob_endpoint
  }
}
