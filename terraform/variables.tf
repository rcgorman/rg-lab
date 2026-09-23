variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, for example https://pve.example.com:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in USER@REALM!TOKEN_ID=SECRET format."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow insecure TLS when Proxmox uses a self-signed certificate."
  type        = bool
  default     = false
}

variable "node_name" {
  description = "Default Proxmox node to create VMs on."
  type        = string
}

variable "proxmox_ssh_username" {
  description = "SSH user for provider-side Proxmox operations."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Private key path for provider-side Proxmox SSH operations."
  type        = string
  default     = "~/.ssh/id_ed25519_terraform"
}

variable "image_id" {
  description = "Proxmox import file ID for the bootc qcow2 image, for example local:import/rg-lab-alma10_2-bootc.qcow2."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore for VM disks and EFI disks."
  type        = string
  default     = "local-lvm"
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject into the ansible user with cloud-init."
  type        = list(string)
}

variable "vms" {
  description = "VMs to create from the bootc qcow2 image."
  type = map(object({
    vm_id        = number
    name         = string
    description  = optional(string, "Managed by OpenTofu")
    node_name    = optional(string)
    cpu_cores    = optional(number, 2)
    cpu_type     = optional(string, "x86-64-v3")
    memory_mb    = optional(number, 2048)
    disk_size_gb = optional(number, 20)
    bridge       = optional(string, "vmbr0")
    mac_address  = string
    vlan_id      = optional(number)
    ipv4_address = string
    ipv4_gateway = string
    dns_servers  = optional(list(string), [])
    started      = optional(bool, true)
    on_boot      = optional(bool, true)
    tags         = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = length(distinct([for vm in values(var.vms) : split("/", vm.ipv4_address)[0]])) == length(var.vms)
    error_message = "Every VM must have a unique ipv4_address."
  }

  validation {
    condition     = length(distinct([for vm in values(var.vms) : lower(vm.mac_address)])) == length(var.vms)
    error_message = "Every VM must have a unique mac_address."
  }

  validation {
    condition     = alltrue([for vm in values(var.vms) : can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", vm.mac_address))])
    error_message = "Each mac_address must be six colon-separated hexadecimal octets."
  }

  validation {
    condition = alltrue([for vm in values(var.vms) :
      can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}/[0-9]{1,2}$", vm.ipv4_address)) &&
      can(cidrhost(vm.ipv4_address, 0))
    ])
    error_message = "Each ipv4_address must use IPv4 CIDR notation, for example 10.6.13.21/24."
  }

  validation {
    condition = alltrue([for vm in values(var.vms) :
      can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", vm.ipv4_gateway)) &&
      can(cidrhost("${vm.ipv4_gateway}/32", 0))
    ])
    error_message = "Each ipv4_gateway must be an IPv4 address without a prefix."
  }

  validation {
    condition     = length(distinct([for vm in values(var.vms) : vm.vm_id])) == length(var.vms)
    error_message = "Every VM must have a unique vm_id."
  }
}
