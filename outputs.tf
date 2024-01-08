output "public_ip_address_vm1" {
  value = azurerm_linux_virtual_machine.my_terraform_vm[0].public_ip_address
}

output "public_ip_address_vm2" {
  value = azurerm_linux_virtual_machine.my_terraform_vm[1].public_ip_address
}
