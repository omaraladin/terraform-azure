# Configure the AzureRM provider
# This block specifies that Terraform will use the Azure Resource Manager (AzureRM) provider.
# The 'features {}' block is often included to enable certain provider features,
# though it's not strictly necessary for basic operations.
provider "azurerm" {
  features {}
}

# Define a Resource Group
# A Resource Group is a logical container for Azure resources.
# All resources in this example will be deployed into this Resource Group.
resource "azurerm_resource_group" "rg" {
  name     = "my-terraform-rg" # Name of the Resource Group
  location = "East US"         # Azure region where the Resource Group will be created
}

# Define a Virtual Network (VNet)
# A VNet is the fundamental building block for your private network in Azure.
# It allows many types of Azure resources to securely communicate with each other,
# the internet, and on-premises networks.
resource "azurerm_virtual_network" "vnet" {
  name                = "my-terraform-vnet"
  address_space       = ["10.0.0.0/16"] # The address space for the VNet
  location            = azurerm_resource_group.rg.location # Inherit location from the Resource Group
  resource_group_name = azurerm_resource_group.rg.name
}

# Define a Subnet
# Subnets enable you to segment the virtual network into one or more sub-networks
# and allocate a portion of the VNet's address space to each subnet.
resource "azurerm_subnet" "subnet" {
  name                 = "my-terraform-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"] # The address prefix for the subnet
}

# Define a Network Security Group (NSG)
# An NSG contains security rules that allow or deny inbound network traffic
# to, or outbound network traffic from, several types of Azure resources.
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
    source_address_prefix      = "*"  # Allow from any IP address
    destination_address_prefix = "*"
  }
}

# Define a Public IP address
# A Public IP address allows internet-facing communication to Azure resources.
resource "azurerm_public_ip" "public_ip" {
  name                = "my-terraform-publicip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static" # Static IP ensures the IP address doesn't change
}

# Define a Network Interface (NIC)
# A NIC enables an Azure Virtual Machine to communicate with the internet,
# Azure, and on-premises resources.
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
# It's generally recommended to associate NSGs at the subnet level for broader control.
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Define a Virtual Machine
# This block creates an Ubuntu Server VM.
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "my-terraform-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B1s" # VM size (e.g., Standard_B1s, Standard_DS1_v2)
  admin_username      = "azureuser"    # Administrator username for the VM

  # SSH Key for authentication (replace with your actual public key or generate one)
  # For production, it's recommended to use a more secure method for key management.
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

# Output the Public IP address of the VM
# This output will display the public IP address after Terraform applies the configuration.
output "public_ip_address" {
  value       = azurerm_public_ip.public_ip.ip_address
  description = "The public IP address of the Azure Virtual Machine."
}

# Output the SSH command
output "ssh_command" {
  value       = "ssh ${azurerm_linux_virtual_machine.vm.admin_username}@${azurerm_public_ip.public_ip.ip_address}"
  description = "SSH command to connect to the Azure Virtual Machine."
}
