output "jumpbox_public_ip_fqdn" {
   value = azurerm_public_ip.vm1.fqdn
}

output "jumpbox_public_ip" {
   value = azurerm_public_ip.vm1.ip_address
}
