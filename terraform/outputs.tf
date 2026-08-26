output "vms" {
  description = "VM IDs and guest-agent reported addresses."
  value = {
    for name, vm in module.vm : name => {
      id             = vm.id
      name           = vm.name
      ipv4_addresses = vm.ipv4_addresses
    }
  }
}
