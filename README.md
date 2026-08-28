# rg-lab

My homelab infrastructure built around:

- `bootc` for the VM operating system image
- `Ansible` for host and service configuration
- `OpenTofu` for VM provisioning

## Current Direction

The VM base image:

- AlmaLinux 10 bootc base
- cloud-init and qemu-guest-agent for VM provisioning
- firewalld, chrony, SELinux enforcing defaults
- NetBird client installed in the host image

Service deployment should be VM-by-VM:

1. OpenTofu creates or updates a VM from the bootc disk image.
2. The VM joins the management network with NetBird.
3. Semaphore runs an Ansible playbook against that VM.
4. The playbook enrolls or configures the VM, then calls one role per service.
5. Service roles render Podman quadlets into `/etc/containers/systemd/` and any needed config files in `/srv/quadlet/servicename/`
