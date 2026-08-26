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

variable "vlan_id" {
  type    = number
  default = null
}

variable "ipv4_address" {
  type = string
}

variable "ipv4_gateway" {
  type = string
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
