provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  ssh {
    agent       = true
    username    = var.proxmox_ssh_username
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}
