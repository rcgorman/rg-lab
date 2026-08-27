# Ansible

This directory is organized around VM intent.

## Inventory Groups

- `bootc_hosts`: every bootc VM that should get baseline host config and NetBird.
- `semaphore_hosts`: the management VM running Semaphore UI and automation tooling.
- `secrets_hosts`: sensitive services such as Vaultwarden, Infisical, and Keycloak.
- `data_hosts`: higher-value data apps such as Immich, OpenCloud, and document management.
- `apps_hosts`: lower-criticality apps and experiments.

## Playbooks

- `playbooks/base.yml`: common host config for all bootc hosts.
- `playbooks/netbird.yml`: enroll bootc hosts with NetBird.
- `playbooks/semaphore.yml`: deploy Semaphore UI only.
- `playbooks/vaultwarden.yml`: deploy Vaultwarden only.
- `playbooks/site.yml`: run the current full site configuration.

Secrets should come from the shell during local testing and Semaphore environment secrets later.
