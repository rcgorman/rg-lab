# Lightweight Monitoring

Deployment smoke tests run automatically at the end of `site.yml` and verify
the systemd units plus these local endpoints:

| Service | Local probe |
| --- | --- |
| Vaultwarden | `http://127.0.0.1:18080/alive` |
| Immich | `http://127.0.0.1:2283/api/server/ping` |
| OpenCloud | `http://127.0.0.1:9200/healthz` |

These tests catch deployment failures but are not continuous monitoring.

## External Availability Checks

Use a small availability monitor such as Uptime Kuma from a system independent
of the two workload VMs. Check the trusted HAProxy frontends, not only backend
ports, so DNS, certificates, routing, and applications are exercised together.

- `https://vault.internal.gormantech.com/alive`
- `https://cloud.internal.gormantech.com/healthz`
- Immich trusted frontend and `/api/server/ping`: **record after confirming its
  DNS name**.
- Proxmox API/management frontend.
- TrueNAS management endpoint.

Use a five-minute interval initially and alert only after two or three
consecutive failures to avoid noise during deliberate reboots.

## Backup and Storage Checks

Backup freshness is more important than general uptime. Add checks for:

- Latest successful `rg-backup-*.service` runs.
- Latest successful `rg-restic-backup.service` run on both VMs.
- Age of the newest Restic snapshot for each repository.
- Restic repository check and maintenance results.
- TrueNAS pool health, SMART tests, scrubs, snapshots, and off-site replication.

Select one notification destination that is usable when Vaultwarden or the lab
is unavailable. Trigger a controlled test alert after configuration and record
the destination and escalation expectations here.
