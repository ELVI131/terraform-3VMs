# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "3.46.0"
    features {}
}

 resource "azurerm_resource_group" "test" {
   name     = "acctestrg"
   location = "West Europe"
 }

 resource "azurerm_virtual_network" "test" {
   name                = "acctvn"
   address_space     = ["10.0.0.0/16"]
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name
 }

 resource "azurerm_subnet" "test" {
   name                 = "acctsub"
   resource_group_name  = azurerm_resource_group.test.name
   virtual_network_name = azurerm_virtual_network.test.name
   address_prefixes     = ["10.0.2.0/24"]
 }

 resource "azurerm_public_ip" "test" {
   name                         = "publicIPForLB"
   location                     = azurerm_resource_group.test.location
   resource_group_name          = azurerm_resource_group.test.name
   allocation_method            = "Static"
 }

# Creates a Network Security Group and rules
resource "azurerm_network_security_group" "test" {
  name                = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

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
 resource "azurerm_lb" "test" {
   name                = "loadBalancer"
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name

   frontend_ip_configuration {
     name                 = "publicIPAddress"
     public_ip_address_id = azurerm_public_ip.test.id
   }
 }

 resource "azurerm_lb_backend_address_pool" "test" {
   loadbalancer_id     = azurerm_lb.test.id
   name                = "BackEndAddressPool"
 }

 resource "azurerm_network_interface" "test" {
   count               = 3
   name                = "acctni${count.index}"
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name

   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = azurerm_subnet.test.id
     private_ip_address_allocation = "Dynamic"
   }
 }

 resource "azurerm_managed_disk" "test" {
   count                = 3
   name                 = "datadisk_existing_${count.index}"
   location             = azurerm_resource_group.test.location
   resource_group_name  = azurerm_resource_group.test.name
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "100"
 }

 resource "azurerm_availability_set" "avset" {
   name                         = "avset"
   location                     = azurerm_resource_group.test.location
   resource_group_name          = azurerm_resource_group.test.name
   platform_fault_domain_count  = 3
   platform_update_domain_count = 3
   managed                      = true
 }

 resource "azurerm_virtual_machine" "test" {
   count                 = 3
   name                  = "acctvm${count.index}"
   location              = azurerm_resource_group.test.location
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.test.name
   network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"

   # Uncomment this line to delete the OS disk automatically when deleting the VM
   # delete_os_disk_on_termination = true

   # Uncomment this line to delete the data disks automatically when deleting the VM
   # delete_data_disks_on_termination = true

   storage_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "18.04-LTS"
     version   = "latest"
   }

   storage_os_disk {
     name              = "myosdisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   # Optional data disks
   storage_data_disk {
     name              = "datadisk_new_${count.index}"
     managed_disk_type = "Standard_LRS"
     create_option     = "Empty"
     lun               = 0
     disk_size_gb      = "50"
   }

   storage_data_disk {
     name            = element(azurerm_managed_disk.test.*.name, count.index)
     managed_disk_id = element(azurerm_managed_disk.test.*.id, count.index)
     create_option   = "Attach"
     lun             = 1
     disk_size_gb    = element(azurerm_managed_disk.test.*.disk_size_gb, count.index)
   }

   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"

    
     admin_password = "Password1234!"
   }

   os_profile_linux_config {
     disable_password_authentication = false
   }

   tags = {
     environment = "staging"
   }
 }