# Ansible

This directory is organized around VM intent. Baseline host configuration lives in
the bootc image; Ansible handles enrollment and application deployment.

## Inventory Groups

- `bootc_hosts`: every bootc VM that should get NetBird enrollment and bootc updates.
- `identity_hosts`: identity and credential services such as Vaultwarden and Keycloak.
- `data_hosts`: higher-value data apps such as Immich, OpenCloud, and document management.
- `apps_hosts`: lower-criticality apps and experiments.

## Playbooks

- `playbooks/netbird.yml`: enroll bootc hosts with NetBird.
- `playbooks/bootc_upgrade.yml`: upgrade bootc hosts to the latest image they track.
- `playbooks/host_config.yml`: configure mutable host settings.
- `playbooks/admin_users.yml`: configure human admin users.
- `playbooks/vaultwarden.yml`: deploy Vaultwarden only.
- `playbooks/immich.yml`: deploy Immich only.
- `playbooks/opencloud.yml`: deploy OpenCloud with OnlyOffice document editing.
- `playbooks/site.yml`: run the current full site configuration.

Run `playbooks/host_config.yml` once on a new bootc VM before deploying app
playbooks directly. The full `site.yml` wrapper runs it first.

For disaster recovery, use SOPS to provide the encrypted variables in
`secrets.sops.yml` to a single-host site run:

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/site.yml --limit rg-identity01'
```

The bootc image owns baseline services and host settings such as chronyd,
firewalld, qemu-guest-agent, SELinux hardening, and bootc-specific cloud-init
defaults. It also owns baseline users and `containers` subuid/subgid mappings.
The `ansible` account is created with passwordless sudo, but SSH keys and human
password hashes are still injected outside the image. Mutable host configuration
such as firewall zone services is handled by Ansible.

Proxmox cloud-init exclusively owns host networking. Do not add NetworkManager
profiles or disable cloud-init networking from Ansible. Bootc upgrades run one
host at a time and verify that each host returns on its configured inventory IP
before proceeding.

Secrets are encrypted in Git with SOPS and age. `sops exec-env` exposes them
only to the Ansible child process. Service playbooks read those environment
variables and create Podman secrets on the target before quadlets are started.
Podman does not expose stored secret values for comparison. To intentionally
replace an existing secret, run its service playbook with
`-e podman_secrets_recreate=true`; the affected containers will restart after
the secret is recreated.
Secret values should include `RYAN_SSH_PUBLIC_KEY` and `RYAN_PASSWORD_HASH`.
Ryan can use the password
at the VM console and for sudo, and the key over SSH. SSH password authentication
is disabled. The `ansible` service account has no usable password, accepts its
cloud-init-provisioned SSH key, and has passwordless sudo for automation. The
`admin_users` role manages only the `ansible` and `ryan` accounts; it does not
remove unrelated users.
NAS-backed app data is mounted with Podman named NFS volumes instead of host `/mnt/...` bind mounts.

## OpenCloud And OnlyOffice

The full OpenCloud stack uses the stable `opencloudeu/opencloud:7.2.4` image and
the pinned `onlyoffice/documentserver:9.3.1` image. OpenCloud data remains on the
TrueNAS-backed `opencloud-data` volume. OnlyOffice's application, library,
Postgres, and RabbitMQ state use local named volumes on `rg-data01`.

The generated `ONLYOFFICE_JWT_SECRET` is stored in `secrets.sops.yml`. Deploy the
complete stack with:

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/opencloud.yml --private-key "$HOME/.ssh/id_ed25519_terraform"'
```

The reverse proxy needs these routes:

- `cloud.internal.gormantech.com` to `http://10.6.13.22:9200`
- `office.internal.gormantech.com` to `http://10.6.13.22:18081`

HAProxy terminates TLS for both services. The OnlyOffice backend must use plain
HTTP rather than SSL. The HTTPS frontend must also send these headers so
OnlyOffice advertises secure WOPI endpoints:

```haproxy
http-request set-header X-Forwarded-Proto https
http-request set-header X-Forwarded-Host %[req.hdr(host)]
http-request set-header X-Forwarded-Port 443
```
