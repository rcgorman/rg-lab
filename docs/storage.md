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
| Restic repositories | `/mnt/Storage/restic` | Writable by rest-server; private per-host paths with append-only client access |

Podman mounts the two NFS application datasets directly through Quadlet named
volumes. They are not host `/mnt` mounts, and they must not be repurposed as the
Restic repository.

## Planned Snapshot Policy

Configure TrueNAS periodic snapshot tasks for the application datasets and the
Restic repository dataset. The following are intended schedules, not tasks
managed by this repository. Set the TrueNAS timezone to `America/New_York` so
these are Eastern wall-clock times, including daylight saving time.

| Dataset | Schedule | Lifetime |
| --- | --- | --- |
| `Storage/immich` | Daily at 01:00 | 30 days |
| `Storage/immich` | Monthly at 01:00 | 6 months |
| `Storage/opencloud` | Daily at 01:00 | 30 days |
| `Storage/opencloud` | Monthly at 01:00 | 6 months |
| `Storage/restic` | Daily at 01:00 | 30 days |
| `Storage/restic` | Monthly at 01:00 | 6 months |

Run the monthly tasks on the first day of each month. The VM backup chain starts
at 10:00 p.m. Eastern, with up to 20 minutes of random delay, so the 1:00 a.m.
snapshots are about 2 hours 40 minutes after the latest scheduled start, minus
the time needed to complete the backup chain. Confirm it actually finishes
before the snapshots as storage use grows.

Record the exact TrueNAS task names after confirming them in the UI. SMART
tests, the scrub schedule, pool-health alerts, and their notification
destination also remain to be recorded.

An off-box target is intentionally deferred. Snapshots on the same TrueNAS
system protect history but cannot protect against loss of the TrueNAS system or
site; `docs/backup.md` records this as an accepted risk.
