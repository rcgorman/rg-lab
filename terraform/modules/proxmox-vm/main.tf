resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = var.description
  node_name   = var.node_name
  vm_id       = var.vm_id
  tags        = var.tags

  machine = "q35"
  bios    = "ovmf"

  started         = var.started
  on_boot         = var.on_boot
  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
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
    size         = var.disk_size_gb
  }

  initialization {
    datastore_id = var.datastore_id
    upgrade      = false

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []

      content {
        servers = var.dns_servers
      }
    }

    user_account {
      username = "ansible"
      keys     = var.ssh_public_keys
    }
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }
}
