output "id" {
  value = proxmox_virtual_environment_vm.this.id
}

output "name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "ipv4_addresses" {
  value = proxmox_virtual_environment_vm.this.ipv4_addresses
}

output "configured_ipv4_address" {
  value = var.ipv4_address
}

output "mac_address" {
  value = var.mac_address
}
