locals {
  common_tags = ["opentofu", "bootc", "almalinux10"]
}

module "vm" {
  source = "./modules/proxmox-vm"

  for_each = var.vms

  name            = each.value.name
  vm_id           = each.value.vm_id
  description     = each.value.description
  node_name       = coalesce(each.value.node_name, var.node_name)
  image_id        = var.image_id
  datastore_id    = var.datastore_id
  ssh_public_keys = var.ssh_public_keys

  cpu_cores    = each.value.cpu_cores
  cpu_type     = each.value.cpu_type
  memory_mb    = each.value.memory_mb
  disk_size_gb = each.value.disk_size_gb
  bridge       = each.value.bridge
  vlan_id      = each.value.vlan_id
  ipv4_address = each.value.ipv4_address
  ipv4_gateway = each.value.ipv4_gateway
  dns_servers  = each.value.dns_servers
  started      = each.value.started
  on_boot      = each.value.on_boot
  tags         = concat(local.common_tags, each.value.tags)
}
