resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vms

  name        = each.value.name
  description = each.value.description
  node_name   = coalesce(each.value.node_name, var.node_name)
  vm_id       = each.value.vm_id
  tags        = concat(["opentofu", "bootc", "almalinux10"], each.value.tags)

  machine = "q35"
  bios    = "ovmf"

  boot_order = ["virtio0"]

  started         = each.value.started
  on_boot         = each.value.on_boot
  stop_on_destroy = true

  agent {
    enabled = true

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = each.value.cpu_cores
    type  = each.value.cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
  }

  disk {
    datastore_id = var.datastore_id
    import_from  = var.image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = each.value.disk_size_gb
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "ide2"
    upgrade      = false

    ip_config {
      ipv4 {
        address = each.value.ipv4_address
        gateway = each.value.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(each.value.dns_servers) > 0 ? [1] : []

      content {
        servers = each.value.dns_servers
      }
    }

    user_account {
      username = "ansible"
      keys     = var.ssh_public_keys
    }
  }

  network_device {
    bridge       = each.value.bridge
    mac_address  = each.value.mac_address
    model        = "virtio"
    disconnected = false
    vlan_id      = each.value.vlan_id
  }

  operating_system {
    type = "l26"
  }
}

# Preserve existing VM state addresses when flattening the former wrapper module.
moved {
  from = module.vm["identity"].proxmox_virtual_environment_vm.this
  to   = proxmox_virtual_environment_vm.vm["identity"]
}

moved {
  from = module.vm["data"].proxmox_virtual_environment_vm.this
  to   = proxmox_virtual_environment_vm.vm["data"]
}
