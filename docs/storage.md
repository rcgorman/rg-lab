# Storage

TrueNAS at `10.6.13.5` owns bulk application data. Workload VMs own only the
local state that needs an application-aware backup before Restic can upload it.

## Current Datasets and Volumes

| Workload | Location | Required ownership/behavior |
| --- | --- | --- |
| Immich library | `10.6.13.5:/mnt/Storage/immich` | Writable by container UID/GID `3000`; preserve NFS identity mapping |
| Immich PostgreSQL | local Podman volume `immich-postgres` | Back up with a logical PostgreSQL dump |
| Immich model cache | local Podman volume `immich-model-cache` | Rebuildable; no recovery backup required |
| OpenCloud data | `10.6.13.5:/mnt/Storage/opencloud` | Writable by container UID/GID `3001`; preserve NFS identity mapping |
| OpenCloud configuration | `/srv/quadlet/opencloud` on `rg-data01` | Included in application backup artifacts |
| Vaultwarden | local Podman volume `vaultwarden-data` | Back up SQLite consistently plus attachments, Sends, keys, and config |

Podman mounts the two NFS application datasets directly through Quadlet named
volumes. They are not host `/mnt` mounts, and they must not be repurposed as the
Restic repository.

## Snapshot Policy To Configure

The exact TrueNAS task names and retention are not yet recorded. Before enabling
backups, document and configure:

- Periodic snapshots for the Immich and OpenCloud datasets.
- A separate dataset for Restic repositories on the new SSD-backed pool.
- Snapshot retention for the Restic dataset that does not conflict with
  rest-server maintenance.
- SMART tests, scrub schedule, pool-health alerts, and alert destination.
- An off-box replication or backup target for both application datasets and the
  Restic repositories.

Snapshots on the same TrueNAS system protect history but are not an off-site
copy. Do not count the plan as complete until a copy leaves that box.

## Legacy OnlyOffice State

The Ansible role stops OnlyOffice and removes its definitions, but deliberately
does not delete `onlyoffice-data`, `onlyoffice-lib`, `onlyoffice-postgres`, or
`onlyoffice-rabbitmq`. Confirm OpenCloud works without the integration and retain
anything needed before manually deleting those volumes.
