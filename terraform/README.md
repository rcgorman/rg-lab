# Terraform / OpenTofu

This layer will eventually provision VMs from the `bootc` disk image.

Keep this layer focused on infrastructure facts:

- VM name and ID
- CPU and memory
- disk size
- network and VLAN
- static IP or cloud-init network config
- SSH key injection for the `ansible` user

Application containers should not be defined here. They belong in Ansible roles as Podman quadlets.
