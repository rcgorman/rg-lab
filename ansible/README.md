# Ansible

This directory is organized around VM intent. Baseline host configuration lives in
the bootc image; Ansible handles enrollment and application deployment.

## Inventory Groups

- `bootc_hosts`: every bootc VM that should get NetBird enrollment and bootc updates.
- `semaphore_hosts`: the management VM running Semaphore UI and automation tooling.
- `secrets_hosts`: sensitive services such as Vaultwarden, Infisical, and Keycloak.
- `data_hosts`: higher-value data apps such as Immich, OpenCloud, and document management.
- `apps_hosts`: lower-criticality apps and experiments.

## Playbooks

- `playbooks/netbird.yml`: enroll bootc hosts with NetBird.
- `playbooks/semaphore.yml`: deploy Semaphore UI only.
- `playbooks/vaultwarden.yml`: deploy Vaultwarden only.
- `playbooks/site.yml`: run the current full site configuration.

The bootc image owns baseline services and host settings such as chronyd,
firewalld, qemu-guest-agent, and the `containers` subuid/subgid mappings needed
for system quadlets using `UserNS=auto`.

Secrets should come from the shell during local testing and Semaphore environment secrets later.
