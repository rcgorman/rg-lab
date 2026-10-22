# Backup and Restore

## Current Status

The application-backup and Restic roles remain intentionally separate from
`site.yml`. Their role defaults enable the timers after the primary repositories
and a test restore were validated on 2026-10-19. Apply this configuration
explicitly with the SOPS-wrapped `backups.yml` playbook so repository
credentials are available during the run.

Server-side Restic maintenance, TrueNAS snapshot timers, and failure alerts
remain to be configured. An off-site copy is intentionally deferred; this is an
accepted single-site risk, not a blocker for operating the current backup
system.

Ansible installs the generated backup helpers under `/etc/rg-lab/libexec` because
bootc keeps `/usr`, including `/usr/local`, read-only at runtime. The systemd
services invoke these helpers through `/usr/bin/bash` so their host-managed
location works with SELinux enforcing.

The intended data flow is:

```text
VM-local state
  -> application-consistent artifact in /var/backups/rg-lab
  -> Restic repository on TrueNAS

TrueNAS Immich/OpenCloud datasets
  -> planned periodic ZFS snapshots

Optional future improvement
  -> independent off-site copy of both protection paths
```

## Application Artifacts

| Host | Artifacts, in execution order | Nightly start |
| --- | --- | --- |
| `rg-identity01` | Vaultwarden SQLite backup plus files and keys, then Restic upload | 10:00 p.m. Eastern, plus up to 20 minutes of random delay |
| `rg-data01` | Compressed Immich PostgreSQL dump, OpenCloud configuration, then Restic upload | 10:00 p.m. Eastern, plus up to 20 minutes of random delay |

Each VM has one persistent timer, `rg-restic-backup.timer`. Its service runs the
application backups sequentially and uploads only if every application backup
succeeds. A missed run starts after the host returns. Local artifacts are
retained for seven days. The timer uses `America/New_York`, so it remains at
10:00 p.m. local time through EST/EDT changes. The planned 1:00 a.m. Eastern
TrueNAS snapshots should run after the upload; check actual completion times as
data grows.

## TrueNAS Restic Prerequisites

1. Install and configure rest-server on the SSD-backed dataset.
2. Create one private repository/credential pair per VM.
3. Give workload credentials append-only access.
4. Initialize each repository and save its repository password in the encrypted
   recovery kit as well as SOPS.
5. Configure server-side forget/prune maintenance with credentials unavailable
   to the workload VMs.
6. Configure a backup-failure notification destination.

The required host-specific SOPS environment keys are documented in
`ansible/README.md`. For a new repository, first deploy with the single timer
disabled, run the application backup services manually, inspect their artifacts,
then start the Restic service and test a restore. Override the enabled role
default during that bootstrap run:

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/backups.yml -e restic_client_timer_enabled=false'
```

After the restore test passes, rerun the playbook without the override to
enable scheduled operation.

## Disposable Restore Test

Record the date, source snapshot ID, operator, and outcome for every test.

1. Create an isolated disposable VM from the recorded bootc image digest.
2. Run baseline host configuration, then configure backups with
   `restic_client_timer_enabled=false`. Do not start the application playbooks
   before choosing and staging the existing-data restore path.
3. Restore `/var/backups/rg-lab` from a selected Restic snapshot.
4. Restore Vaultwarden into an empty `vaultwarden-data` volume and verify login,
   attachments, Sends, and administrative access.
5. Restore the Immich PostgreSQL dump, attach a read-only copy or clone of the
   matching media dataset, and verify accounts, albums, search, and sample media.
6. Restore OpenCloud configuration, attach a clone of its matching dataset, and
   verify login, file listing, download, upload, and sync.
7. Destroy the disposable VM and retain the test record outside the repository.

## Required Alerts

Before declaring backups complete, alert on:

- Any failed `rg-backup-*.service` or `rg-restic-backup.service` run.
- No successful application artifact within its expected interval.
- No recent Restic snapshot for either VM.
- Restic repository check or server-side maintenance failure.
- TrueNAS pool degradation, failed SMART tests, and missed snapshots.

The notification transport is intentionally undecided; choose it alongside the
TrueNAS deployment rather than embedding an unmonitored placeholder.

## Accepted Single-Site Risk

Off-site replication is deferred with no committed delivery date. Restic and
ZFS snapshots on the same TrueNAS system protect against client compromise,
accidental deletion, and many logical failures, but they do not protect against
loss of the TrueNAS system or site through theft, fire, flood, or a pool-wide
failure. Revisit this decision if the cost or availability constraints change.
