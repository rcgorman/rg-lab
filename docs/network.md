# Network and Routing

This file records infrastructure that is required by the repository but is
configured outside it. Update it whenever OPNsense, DNS, HAProxy, Proxmox, or
NetBird changes.

## Address Plan

| System | Address | Purpose |
| --- | --- | --- |
| OPNsense | `10.6.13.1` | VM gateway and DNS resolver |
| TrueNAS | `10.6.13.5` | Application datasets and future Restic service |
| Proxmox | `10.6.13.10` | Hypervisor API and management |
| `rg-identity01` | `10.6.13.21` | Vaultwarden |
| `rg-data01` | `10.6.13.22` | Immich and OpenCloud |

The workload network is `10.6.13.0/24` on `vmbr0`. The repository does not yet
record the OPNsense interface name or VLAN ID; add them here before relying on
this document for a full network rebuild.

## Application Routing

HAProxy terminates trusted TLS and forwards normal application traffic over the
LAN. The required routes currently known to Git are:

| Frontend | Backend |
| --- | --- |
| `vault.internal.gormantech.com` | `http://10.6.13.21:18080` |
| `cloud.internal.gormantech.com` | `http://10.6.13.22:9200` |
| Immich frontend name: **record in this file** | `http://10.6.13.22:2283` |

Remove the obsolete `office.internal.gormantech.com` DNS entry, certificate
name, and HAProxy backend after deploying the OpenCloud change that removes
OnlyOffice.

Record the following external configuration here when verified:

- OPNsense interface/VLAN and firewall rule names.
- DNS override records and their TTLs.
- HAProxy frontend, certificate, ACL, and backend names.
- Whether backend health checks use `/alive`, `/api/server/ping`, and `/healthz`.

## Administrative Routing

NetBird is the administrative path and is not required for application traffic.
The clients enroll against `https://netbird.gormantech.com`. Limit NetBird policy
to management protocols and administrators, and record peer groups and ACL names
here after reviewing the NetBird control plane.

SSH is key-only, root SSH is disabled, and the host firewalld baseline allows
SSH. The `ansible` account is for automation; `ryan` is the human administrator.

## Rebuild Checks

1. Verify gateway and DNS reachability from each VM console.
2. Verify the stable IP/MAC pairs in `ansible/inventory/lab.yml` and
   `terraform/tofu.tfvars`.
3. Verify each HAProxy backend directly from the proxy host.
4. Verify each trusted frontend from a normal client.
5. Verify NetBird administration independently of HAProxy and internal DNS.
