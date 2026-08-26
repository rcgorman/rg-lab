# rg-lab

Homelab infrastructure built around the BAT pattern:

- `bootc` for the VM operating system image
- Ansible for host and service configuration
- Terraform/OpenTofu for VM provisioning

## Current Direction

The first milestone is the VM base image:

- AlmaLinux 10 bootable container base
- Podman quadlet support
- cloud-init and qemu-guest-agent for VM provisioning
- firewalld, chrony, SELinux enforcing defaults
- NetBird client installed in the host image

After that, service deployment should be VM-by-VM:

1. Terraform/OpenTofu creates or updates a VM from the bootc disk image.
2. The VM joins the management network with NetBird.
3. Semaphore runs an Ansible playbook against that VM.
4. The playbook applies common host settings and then calls one role per service.
5. Service roles render Podman quadlets into `/etc/containers/systemd/`.

## Repository Layout

```text
bootc/
  Containerfile          # AlmaLinux 10 bootc host image
  files/                 # Files copied into the host image
  README.md              # bootc build and install notes

ansible/
  ansible.cfg
  inventory/
  playbooks/
  roles/

terraform/
```

## Deployment

