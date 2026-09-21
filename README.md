# rg-lab

My homelab infrastructure built around:

- `bootc` for the VM operating system image
- `Ansible` from an administrator workstation for host and service configuration
- `OpenTofu` for VM provisioning
- `SOPS` with `age` for encrypted secrets in Git

## Current Direction

The VM base image:

- AlmaLinux 10 bootc base
- cloud-init and qemu-guest-agent for VM provisioning
- firewalld, chrony, SELinux enforcing defaults
- NetBird client installed in the host image

Service deployment should be VM-by-VM:

1. OpenTofu creates or updates a VM from the bootc disk image.
2. SOPS decrypts the required secrets only for the local Ansible process.
3. Ansible configures the host, enrolls NetBird, and calls one role per service.
4. Service roles render Podman quadlets into `/etc/containers/systemd/` and any needed config files in `/srv/quadlet/servicename/`.

A workstation can recreate and configure any single VM directly from this
repository. See [`RECOVERY.md`](RECOVERY.md) for the recovery kit and exact
rebuild sequence.
