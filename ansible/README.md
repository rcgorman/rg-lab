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
defaults. It also owns the `ansible` bootstrap account and `containers`
subuid/subgid mappings. The `ansible` account has passwordless sudo; cloud-init
supplies its SSH key. Ansible creates `ryan` and manages his SSH key, home
permissions, password hash, and wheel membership for password-required sudo.
Mutable host configuration
such as firewall zone services is handled by Ansible.

Proxmox cloud-init exclusively owns host networking. Do not add NetworkManager
profiles or disable cloud-init networking from Ansible. Bootc upgrades run one
host at a time and verify that each host returns on its configured inventory IP
before proceeding.

Secrets are encrypted in Git with SOPS and age. `sops exec-env` exposes them
only to the Ansible child process. Service playbooks read those environment
variables and create Podman secrets on the target before quadlets are started.
The role checks whether a secret exists; it deliberately does not read its value
back or compare plaintext. Podman secrets are not encrypted storage against a
host administrator. To intentionally
replace an existing secret, run its service playbook with
`-e podman_secrets_recreate=true`; the affected containers will restart after
the secret is recreated.
Replacing a Podman secret does not change a password already stored inside
Postgres or OpenCloud. Rotate that application account separately and keep its
SOPS value in sync. Do not delete a database volume to rotate credentials.
Secret values should include `RYAN_SSH_PUBLIC_KEY` and `RYAN_PASSWORD_HASH`.
Ryan can use the password
at the VM console and for sudo, and the key over SSH. SSH password authentication
is disabled. The `ansible` service account has no usable password, accepts its
cloud-init-provisioned SSH key, and has passwordless sudo for automation. The
`admin_users` role manages only the `ansible` and `ryan` accounts; it does not
remove unrelated users.
NAS-backed app data is mounted with Podman named NFS volumes instead of host `/mnt/...` bind mounts.

## Service Definitions

Each service playbook calls one application role. Its `tasks/main.yml` lists the
secrets, configuration tasks, and units to deploy. Native Quadlet definitions
live in that role's `templates/*.container.j2`, `*.network.j2`, and `*.volume.j2`
files. The OpenCloud role also contains OnlyOffice, its CSP, and its application
registry. No application appends to a shared host fact.

The small `podman_secrets` and `podman_quadlet` helpers handle secret creation,
copying units, daemon reload, and container startup. `Network=app.network` and
`Volume=data.volume:/data` let Quadlet order the dependency units. `[Install]`
starts containers at boot; generated units are not enabled with `systemctl enable`.

Existing named volumes are reused, not erased or reformatted. Editing a `.volume`
file does not change an existing volume's driver/options. Inspect and plan any
storage migration separately; never delete a volume to make a playbook pass.
Do not run `restorecon` over active `:Z` bind mounts: Podman manages their labels.

All application image references are centralized in
`inventory/group_vars/all/container_versions.yml` and use explicit version tags,
not digests, `latest`, or major-only tags. Immich server and machine-learning
share `immich_version`. The Postgres image retains its vendor's composite
Postgres/VectorChord/pgvectors version tag. Tags can be republished by upstream;
they are easier to read but do not provide digest-level immutability.
Container auto-update labels remain omitted: review changes in Git and redeploy
deliberately. These variables load with the repository inventory; an alternate
inventory must also supply this file or equivalent `container_images` values.

Run the local definition checks from the repository root:

```bash
ansible-playbook ansible/playbooks/site.yml --syntax-check
ansible-playbook ansible/tests/quadlets.yml
```

These checks do not start containers or validate Linux/SELinux/NFS behavior.

## Human Account Provisioning

New bootc images create only `ansible`. Until `admin_users.yml` has run with
`RYAN_SSH_PUBLIC_KEY` and `RYAN_PASSWORD_HASH`, a new VM has no usable Ryan console
login. Keep the bootstrap SSH key accessible independently of Vaultwarden.

For existing VMs, run this role before upgrading to the image without `ryan`,
then verify the account after the upgrade using the `ansible` SSH account:

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/admin_users.yml --private-key "$HOME/.ssh/id_ed25519_terraform"'
```

The role marks the account as Ansible-managed and retains an existing UID. It
does not delete or recreate the account or its home directory. Verify Ryan's
console login and password-required sudo before relying on them for recovery.

## Secret Rotation

Rotation is deliberately an operator action, not an automatic consequence of
editing SOPS. A normal deployment creates missing Podman secrets and leaves
existing ones unchanged, without reading their contents back or storing hashes.
Therefore a SOPS edit alone does **not** rotate an existing Podman secret.

For a runtime secret such as Vaultwarden's admin token:

1. Edit the encrypted file with `sops ansible/secrets.sops.yml`.
2. Run the relevant service playbook with explicit replacement enabled.
3. Verify the new credential works and the old credential no longer does.

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/vaultwarden.yml --limit rg-identity01 -e podman_secrets_recreate=true'
```

This flag replaces **all** Podman secrets defined by that service playbook and
restarts its containers. Use the individual service playbook, not `site.yml`,
for rotation. Normal deployments should omit the flag.

| Value | Existing-installation behavior |
| --- | --- |
| `VAULTWARDEN_ADMIN_TOKEN` | Replace the Podman secret and restart Vaultwarden. |
| `ONLYOFFICE_JWT_SECRET` | Coordinate with any JWT clients, then replace and restart the OpenCloud/OnlyOffice stack. |
| `IMMICH_DB_PASSWORD` | During maintenance, change the actual Postgres account password and match it in SOPS; then replace the secret and redeploy. |
| `OPENCLOUD_ADMIN_PASSWORD` | Bootstrap value only. Change/reset the existing account through OpenCloud, not just its Podman secret. |
| `RYAN_PASSWORD_HASH`, `RYAN_SSH_PUBLIC_KEY` | Rerun `admin_users.yml`; these are not Podman secrets. |
| `NETBIRD_SETUP_KEY` | Used for enrollment, not to rotate the identity of an already enrolled host. |

Never delete a database or application volume to rotate a password. Check mode
does not perform rotation, and CI never decrypts the SOPS file.

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
