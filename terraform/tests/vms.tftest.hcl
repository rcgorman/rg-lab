# Plans use a mock provider: these tests never contact Proxmox.
mock_provider "proxmox" {}

variables {
  proxmox_endpoint             = "https://pve.invalid:8006/"
  proxmox_api_token            = "test@pve!test=not-a-real-token"
  proxmox_ssh_private_key_path = "tofu.tfvars.example"
  node_name                    = "rg-pve01"
  image_id                     = "local:import/test.qcow2"
  datastore_id                 = "storage"
  ssh_public_keys              = ["ssh-ed25519 test-only"]
  vms = {
    identity = {
      vm_id        = 202
      name         = "rg-identity01"
      mac_address  = "02:52:00:00:02:02"
      ipv4_address = "10.6.13.21/24"
      ipv4_gateway = "10.6.13.1"
      dns_servers  = ["10.6.13.1"]
    }
    data = {
      vm_id        = 203
      name         = "rg-data01"
      mac_address  = "02:52:00:00:02:03"
      ipv4_address = "10.6.13.22/24"
      ipv4_gateway = "10.6.13.1"
      dns_servers  = ["10.6.13.1"]
    }
  }
}

run "preserve_vm_identity_and_cloud_init" {
  command = plan

  assert {
    condition = alltrue([for key, vm in proxmox_virtual_environment_vm.vm :
      vm.vm_id == var.vms[key].vm_id &&
      vm.network_device[0].mac_address == var.vms[key].mac_address &&
      vm.initialization[0].ip_config[0].ipv4[0].address == var.vms[key].ipv4_address &&
      vm.initialization[0].ip_config[0].ipv4[0].gateway == var.vms[key].ipv4_gateway &&
      vm.initialization[0].dns[0].servers == tolist(var.vms[key].dns_servers) &&
      vm.initialization[0].upgrade == false &&
      vm.initialization[0].user_account[0].username == "ansible" &&
      vm.initialization[0].user_account[0].keys == tolist(var.ssh_public_keys) &&
      vm.disk[0].datastore_id == "storage" &&
      vm.disk[0].import_from == var.image_id
    ])
    error_message = "VM identity, disk import, or cloud-init configuration changed."
  }
}

run "reject_duplicate_ip_with_different_prefix" {
  command = plan
  variables {
    vms = {
      one = {
        vm_id        = 202, name = "one", mac_address = "02:52:00:00:02:02"
        ipv4_address = "10.6.13.21/24", ipv4_gateway = "10.6.13.1"
      }
      two = {
        vm_id        = 203, name = "two", mac_address = "02:52:00:00:02:03"
        ipv4_address = "10.6.13.21/25", ipv4_gateway = "10.6.13.1"
      }
    }
  }
  expect_failures = [var.vms]
}

run "reject_invalid_network_identity" {
  command = plan
  variables {
    vms = {
      invalid = {
        vm_id        = 202, name = "invalid", mac_address = "not-a-mac"
        ipv4_address = "10.6.13.999/24", ipv4_gateway = "not-an-ip"
      }
    }
  }
  expect_failures = [var.vms]
}
