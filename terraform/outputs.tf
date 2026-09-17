output "vms" {
  description = "VM IDs, configured network identity, and any guest-agent reported addresses."
  value = {
    for name, vm in module.vm : name => {
      id                      = vm.id
      name                    = vm.name
      configured_ipv4_address = vm.configured_ipv4_address
      mac_address             = vm.mac_address
      ipv4_addresses          = vm.ipv4_addresses
    }
  }
}
