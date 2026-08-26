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
  default     = true
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
  description = "Proxmox file ID for the imported bootc qcow2 image, for example local:import/rg-lab-alma10-bootc.qcow2."
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
    vlan_id      = optional(number)
    ipv4_address = string
    ipv4_gateway = string
    dns_servers  = optional(list(string), [])
    started      = optional(bool, true)
    on_boot      = optional(bool, true)
    tags         = optional(list(string), [])
  }))
  default = {}
}
