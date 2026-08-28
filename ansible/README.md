# Ansible

This directory is organized around VM intent. Baseline host configuration lives in
the bootc image; Ansible handles enrollment and application deployment.

## Inventory Groups

- `bootc_hosts`: every bootc VM that should get NetBird enrollment and bootc updates.
- `semaphore_hosts`: the management VM running Semaphore UI and automation tooling.
- `identity_hosts`: identity and credential services such as Vaultwarden and Keycloak.
- `data_hosts`: higher-value data apps such as Immich, OpenCloud, and document management.
- `apps_hosts`: lower-criticality apps and experiments.

## Playbooks

- `playbooks/netbird.yml`: enroll bootc hosts with NetBird.
- `playbooks/bootc_update.yml`: upgrade bootc hosts to the latest image they track.
- `playbooks/admin_users.yml`: configure human admin users.
- `playbooks/semaphore.yml`: deploy Semaphore UI only.
- `playbooks/vaultwarden.yml`: deploy Vaultwarden only.
- `playbooks/immich.yml`: deploy Immich only.
- `playbooks/opencloud.yml`: deploy OpenCloud only.
- `playbooks/site.yml`: run the current full site configuration.

The bootc image owns baseline services and host settings such as chronyd,
firewalld, qemu-guest-agent, and SELinux hardening. Mutable host configuration
such as `containers` subuid/subgid mappings is handled by Ansible.

Secrets should come from Semaphore environment secrets. 
I might abandon Semaphore and use sops + age in the future.
For now, service playbooks that need Podman secrets read them from environment variables
and create Podman secrets on the target host before quadlets are started.
NAS-backed app data is mounted with Podman named NFS volumes instead of host `/mnt/...` bind mounts.
