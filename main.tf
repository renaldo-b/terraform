 terraform {

   required_version = ">=0.12"

   required_providers {
     azurerm = {
       source = "hashicorp/azurerm"
       version = "~>2.0"
     }
   }
 }

 provider "azurerm" {
   features {}
 }


resource "azurerm_resource_group" "rg-terraform" {
  name = "rg-terraform"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name = "vn-prod"
  location = "West Europe"
  address_space = [ "10.0.0.0/16" ]
  resource_group_name = azurerm_resource_group.rg-terraform.name
}

resource "azurerm_subnet" "sn-prod" {
  name = "sn-prod"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [ "10.0.1.0/24" ]
}

resource "azurerm_public_ip" "pip01" {
  name = "pip01"
  location = "West Europe"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  allocation_method = "Static"
}

resource "azurerm_network_interface" "nic" {
  count = 2
  name = "nic${count.index}"
  location = "West Europe"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  ip_configuration {
    name = "ipconfig01"
    subnet_id = azurerm_subnet.sn-prod.id
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_managed_disk" "disks" {
  count = 2
  name = "datadisk_${count.index}"
  location = "West Europe"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  storage_account_type = "Standard_LRS"
  create_option = "Empty"
  disk_size_gb = "127"
}

resource "azurerm_availability_set" "avset" {
  name = "avset01"
  location = "West Europe"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
  managed = true
}

resource "azurerm_virtual_machine" "vm" {
  count = 2
  name = "test-dc_${count.index}"
  location = "West Europe"
  availability_set_id = azurerm_availability_set.avset.id
  resource_group_name = azurerm_resource_group.rg-terraform.name
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]
  vm_size = "Standard_D2as_v5"
  delete_data_disks_on_termination = true
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2022-datacenter-azure-edition"
    version = "latest"
  }

  storage_os_disk {
    name = "osdisk_${count.index}"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk {
    name = "datadisk_${count.index}"
    caching = "ReadWrite"
    lun = 1
    managed_disk_id = element(azurerm_managed_disk.disks.*.id, count.index) 
    create_option = "Attach"
    disk_size_gb = "127"  
  }

  os_profile_windows_config {
provision_vm_agent = true
}

  os_profile {
    computer_name = "server"
    admin_username = "adm-loc"
    admin_password = ""
  }
}