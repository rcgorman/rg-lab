variable "name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "description" {
  type    = string
  default = "Managed by OpenTofu"
}

variable "node_name" {
  type = string
}

variable "image_id" {
  description = "File ID of the imported bootc qcow2 image, for example local:import/rg-lab-alma10_2-bootc.qcow2."
  type        = string
}

variable "datastore_id" {
  type = string
}

variable "ssh_public_keys" {
  type = list(string)
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "cpu_type" {
  type    = string
  default = "x86-64-v3"
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "disk_size_gb" {
  type    = number
  default = 20
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "mac_address" {
  description = "Stable, unique MAC address for the VM's primary NIC."
  type        = string

  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.mac_address))
    error_message = "mac_address must be six colon-separated hexadecimal octets."
  }
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "ipv4_address" {
  type = string

  validation {
    condition = (
      can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}/[0-9]{1,2}$", var.ipv4_address)) &&
      can(cidrhost(var.ipv4_address, 0))
    )
    error_message = "ipv4_address must use IPv4 CIDR notation, for example 10.6.13.20/24."
  }
}

variable "ipv4_gateway" {
  type = string

  validation {
    condition = (
      can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", var.ipv4_gateway)) &&
      can(cidrhost("${var.ipv4_gateway}/32", 0))
    )
    error_message = "ipv4_gateway must be an IPv4 address without a prefix."
  }
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "started" {
  type    = bool
  default = true
}

variable "on_boot" {
  type    = bool
  default = true
}

variable "tags" {
  type    = list(string)
  default = []
}
