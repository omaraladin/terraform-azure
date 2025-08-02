# Configure the AzureRM provider
provider "azurerm" {
  features {}
}

# Define a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "my-terraform-rg" # Name of the Resource Group
  location = "East US"         # Azure region where the Resource Group will be created
}

# Define a Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "my-terraform-vnet"
  address_space       = ["10.0.0.0/16"] # The address space for the VNet
  location            = azurerm_resource_group.rg.location # Inherit location from the Resource Group
  resource_group_name = azurerm_resource_group.rg.name
}

# Define a Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "my-terraform-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"] # The address prefix for the subnet
}

# Define a Network Security Group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "my-terraform-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Security rule to allow SSH (port 22) from any source
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22" # SSH port
    source_address_prefix      = "187.86.25.145"  # Allow from this Specific IP address
    destination_address_prefix = "*"
  }
}

# Define a Public IP address
resource "azurerm_public_ip" "public_ip" {
  name                = "my-terraform-publicip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static" # Static IP ensures the IP address doesn't change
}

# Define a Network Interface (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "my-terraform-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id # Associate Public IP
  }
}

# Associate the NSG with the Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Define a Virtual Machine with Ubuntu OS
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "my-terraform-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s" # VM size (e.g., Standard_B1s, Standard_DS1_v2)
  admin_username      = "azureuser"    # Administrator username for the VM

  # SSH Key for authentication (replace with your actual public key or generate one)
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub") # Path to your SSH public key
  }

  network_interface_ids = [azurerm_network_interface.nic.id]

  # Operating System image
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Standard Local Redundant Storage
  }
}
