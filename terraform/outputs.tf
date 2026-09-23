output "vms" {
  description = "VM IDs, configured network identity, and any guest-agent reported addresses."
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm : name => {
      id                      = vm.id
      name                    = vm.name
      configured_ipv4_address = var.vms[name].ipv4_address
      mac_address             = var.vms[name].mac_address
      ipv4_addresses          = vm.ipv4_addresses
    }
  }
}
