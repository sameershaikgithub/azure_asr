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

resource "random_string" "vm1dns" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "random_string" "vm2dns" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "azurerm_resource_group" "asr" {
 name     = var.resource_group_name_primary
 location = var.location-primary
 tags     = var.tags
}

resource "azurerm_resource_group" "asr-sec" {
 name     = var.resource_group_name_secondary
 location = var.location-secondary
 tags     = var.tags
}


resource "azurerm_virtual_network" "asr" {
 name                = "asr-vnet"
 address_space       = ["10.0.0.0/16"]
 location            = var.location-primary
 resource_group_name = azurerm_resource_group.asr.name
 tags                = var.tags
}

resource "azurerm_subnet" "asr" {
 name                 = "asr-subnet"
 resource_group_name  = azurerm_resource_group.asr.name
 virtual_network_name = azurerm_virtual_network.asr.name
 address_prefixes       = ["10.0.2.0/24"]
}

#VNET in Secondary region
resource "azurerm_virtual_network" "asr-sec" {
 name                = "asr-vnet-sec"
 address_space       = ["10.0.0.0/16"]
 location            = var.location-secondary
 resource_group_name = azurerm_resource_group.asr-sec.name
 tags                = var.tags
}

resource "azurerm_subnet" "asr-sec" {
 name                 = "asr-subnet"
 resource_group_name  = azurerm_resource_group.asr-sec.name
 virtual_network_name = azurerm_virtual_network.asr-sec.name
 address_prefixes       = ["10.0.2.0/24"]
}

#Public IP for VM1

resource "azurerm_public_ip" "vm1" {
 name                         = "vm1-public-ip"
 location                     = var.location-primary
 resource_group_name          = azurerm_resource_group.asr.name
 allocation_method            = "Static"
 domain_name_label            = "${random_string.vm1dns.result}-ssh"
 tags                         = var.tags
}

resource "azurerm_network_interface" "vm1" {
 name                = "vm1-nic"
 location            = var.location-primary
 resource_group_name = azurerm_resource_group.asr.name

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = azurerm_subnet.asr.id
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = azurerm_public_ip.vm1.id
 }

 tags = var.tags
}

#Public IP for VM2
resource "azurerm_public_ip" "vm2" {
 name                         = "vm2-public-ip"
 location                     = var.location-primary
 resource_group_name          = azurerm_resource_group.asr.name
 allocation_method            = "Static"
 domain_name_label            = "${random_string.vm1dns.result}-ssh"
 tags                         = var.tags
}

resource "azurerm_network_interface" "vm2" {
 name                = "vm2-nic"
 location            = var.location-primary
 resource_group_name = azurerm_resource_group.asr.name

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = azurerm_subnet.asr.id
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = azurerm_public_ip.vm2.id
 }

 tags = var.tags
}

#Storage Account

resource "azurerm_storage_account" "asrstorage-primary" {
  name                     = "asrstorageeastus2"
  resource_group_name      = var.resource_group_name_primary
  location = var.location-primary
  account_tier             = "Standard"
  account_replication_type = "GRS"
    depends_on = [azurerm_resource_group.asr]

  tags = {
    environment = "storageaccount-primary"
  }
}

resource "azurerm_storage_account" "asrstorage-secondary" {
  name                     = "asrstoragecentralus"
  resource_group_name      = var.resource_group_name_secondary
  location = var.location-secondary
  account_tier             = "Standard"
  account_replication_type = "GRS"

  depends_on = [azurerm_resource_group.asr-sec]

  tags = {
    environment = "storageaccount-secondary"
  }
}

resource "azurerm_virtual_machine" "vm1" {
 name                  = "vm1"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.asr.name
 network_interface_ids = [azurerm_network_interface.vm1.id]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Oracle"
   offer     = "Oracle-Linux"
   sku       = "ol8_2-gen2"
   version   = "8.2.13"
 }

 storage_os_disk {
   name              = "vm1-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "vm1"
   admin_username = var.admin_user
   admin_password = var.admin_password
   custom_data = file("web.conf")
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = var.tags
}

#Create VM2


resource "azurerm_virtual_machine" "vm2" {
 name                  = "vm2"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.asr.name
 network_interface_ids = [azurerm_network_interface.vm2.id]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Oracle"
   offer     = "Oracle-Linux"
   sku       = "ol8_2-gen2"
   version   = "8.2.13"
 }

 storage_os_disk {
   name              = "vm2-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "vm2"
   admin_username = var.admin_user
   admin_password = var.admin_password
   custom_data = file("web.conf")
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = var.tags
}

#Create Managed Disks
resource "azurerm_managed_disk" "disk1" {
  name                 = "vm1-data-disk1"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.asr.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk1" {
  managed_disk_id    = azurerm_managed_disk.disk1.id
  virtual_machine_id = azurerm_virtual_machine.vm1.id
  lun                = "10"
  caching            = "ReadWrite"
}


# Create RV

resource "azurerm_recovery_services_vault" "vault" {
    name    = "recoveryvault-eastus12"
    location = var.location-primary
    resource_group_name = var.resource_group_name_primary
    sku     = "Standard"
    soft_delete_enabled = "false"
    depends_on = [azurerm_resource_group.asr]
}

resource "azurerm_recovery_services_vault" "vault-sec" {
    name    = "recoveryvault-centralus12"
    location = var.location-secondary
    resource_group_name = var.resource_group_name_secondary
    sku     = "Standard"
    soft_delete_enabled = "false"
    depends_on = [azurerm_resource_group.asr-sec]
}

resource "azurerm_backup_policy_vm" "policy" {
  name                = "vm-daily-backup-policy"
  resource_group_name = var.resource_group_name_primary
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 10
  }

  retention_weekly {
    count    = 42
    weekdays = ["Sunday", "Wednesday", "Friday", "Saturday"]
  }

  retention_monthly {
    count    = 7
    weekdays = ["Sunday", "Wednesday"]
    weeks    = ["First", "Last"]
  }

  retention_yearly {
    count    = 77
    weekdays = ["Sunday"]
    weeks    = ["Last"]
    months   = ["January"]
  }
}

#Create Backup Vault

resource "azurerm_data_protection_backup_vault" "backupvault" {
  name                = "backupvaulteastus2"
  location = var.location-primary
  resource_group_name = var.resource_group_name_primary
  datastore_type      = "VaultStore"
  redundancy          = "GeoRedundant"
  depends_on = [azurerm_resource_group.asr]

  identity {
          type         = "SystemAssigned" 
        }
}

#Primary & Seconday Recovery Fabric

resource "azurerm_site_recovery_fabric" "primary" {
  name                = "primary-fabric"
  resource_group_name = var.resource_group_name_primary
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  location            = var.location-primary
  depends_on = [azurerm_recovery_services_vault.vault]
}

resource "azurerm_site_recovery_fabric" "secondary" {
  name                = "secondary-fabric"
  resource_group_name = var.resource_group_name_secondary
  recovery_vault_name = azurerm_recovery_services_vault.vault-sec.name
  location            = var.location-secondary
  depends_on = [azurerm_recovery_services_vault.vault-sec]
}

resource "azurerm_site_recovery_protection_container" "primary" {
  name                 = "primary-protection-container"
  resource_group_name  = var.resource_group_name_primary
  recovery_vault_name  = azurerm_recovery_services_vault.vault.name
  recovery_fabric_name = azurerm_site_recovery_fabric.primary.name
  depends_on = [azurerm_site_recovery_fabric.primary]
}

resource "azurerm_site_recovery_protection_container" "secondary" {
  name                 = "secondary-protection-container"
  resource_group_name  = var.resource_group_name_secondary
  recovery_vault_name  = azurerm_recovery_services_vault.vault-sec.name
  recovery_fabric_name = azurerm_site_recovery_fabric.secondary.name
  depends_on = [azurerm_site_recovery_fabric.secondary]
}



#Replication Policy

resource "azurerm_site_recovery_replication_policy" "policy" {
  name                                                 = "policy"
  resource_group_name                                  = var.resource_group_name_primary
  recovery_vault_name                                  = azurerm_recovery_services_vault.vault.name
  recovery_point_retention_in_minutes                  = 24 * 60
  application_consistent_snapshot_frequency_in_minutes = 4 * 60
  depends_on = [azurerm_site_recovery_fabric.secondary]
}

resource "azurerm_site_recovery_protection_container_mapping" "container-mapping" {
  name                                      = "container-mapping"
  resource_group_name                       = var.resource_group_name_secondary
  recovery_vault_name                       = azurerm_recovery_services_vault.vault.name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.primary.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.primary.name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.secondary.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.policy.id
  depends_on = [azurerm_site_recovery_replication_policy.policy]
}
