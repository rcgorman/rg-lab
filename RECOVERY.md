# Homelab Recovery

This runbook assumes every workload VM is gone or inaccessible, but Proxmox,
GitHub, the NAS, Bitwarden, and an administrator workstation are available.

## Recovery Kit

Keep these items outside the workload VMs:

- The Terraform API token and Proxmox SSH private key.
- `terraform/tofu.tfvars` and the latest OpenTofu state backup.
- The SSH private key matching `ssh_public_keys` in `tofu.tfvars`.
- The age private key, stored as a secure attachment in Bitwarden.
- The encrypted `ansible/secrets.sops.yml` file committed to Git.
- Backups of local stateful Podman volumes.
- OpenCloud configuration files from `/srv/quadlet/opencloud`.

The required local volume backups are:

- `vaultwarden-data`.
- `immich-postgres`.

Immich library data and OpenCloud application data are already stored on the
NAS, but their database or configuration still needs to be recoverable.

## Build The Image

1. Push the desired bootc configuration and wait for the GitHub Actions image
   build to complete.
2. Pull the OCI image on an AMD64 Linux system and create the QCOW2 with
   `bootc-image-builder`.
3. Copy it to `/var/lib/vz/import/rg-lab-alma10_2-bootc.qcow2` on Proxmox.
4. Confirm it with `pvesm list local --content import`.

## Recreate One VM

Always rebuild one VM at a time, beginning with `rg-identity01` so Vaultwarden
and the recovery credentials it contains are available first.

```bash
cd terraform
tofu plan -var-file=tofu.tfvars
tofu apply -var-file=tofu.tfvars
```

Do not apply a plan that replaces an unexpected VM or disk. The configured IP
and MAC addresses are stable and must remain paired.

On a rebuilt VM, verify from the Proxmox console:

```bash
cloud-init status --long
nmcli connection show --active
ip -4 address show dev eth0
ip route
```

The active host profile should be `cloud-init eth0`.

## Prepare SOPS And Ansible

Install `sops` and `age` on the administrator workstation. On macOS:

```bash
brew install age sops
```

Restore the age key from Bitwarden to `~/.config/sops/age/keys.txt`. The private
key must never be committed to Git or copied to a managed host.

The repository contains `.sops.yaml` with only the public age recipient and an
encrypted `ansible/secrets.sops.yml`. Verify decryption without printing values:

```bash
sops exec-env ansible/secrets.sops.yml 'test -n "$RYAN_PASSWORD_HASH"'
```

A recreated VM has a new SSH host key. Remove only that VM's old entries, then
verify and accept its new fingerprint through the Proxmox console before using
Ansible.

```bash
ssh-keygen -R rg-identity01
ssh-keygen -R 10.6.13.21
ssh ansible@10.6.13.21
```

## Configure One VM

Run the complete desired configuration directly from the workstation. SOPS
passes decrypted values only to the Ansible child process, and the limit
prevents changes to any other host.

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/site.yml --limit rg-identity01'
```

Use the same pattern for the remaining VMs:

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/site.yml --limit rg-data01'
```

Restore stateful volume data before running the corresponding service playbook
when preserving an existing installation. For a deliberate fresh installation,
let the playbook create empty volumes.

### Fresh Vaultwarden

For a fresh Vaultwarden installation, set `VAULTWARDEN_ADMIN_TOKEN` in
`ansible/secrets.sops.yml`, then temporarily allow registration:

```bash
sops ansible/secrets.sops.yml
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/vaultwarden.yml --limit rg-identity01 -e vaultwarden_signups_allowed=true'
```

Create the Ryan account, import the exported vault, and immediately rerun the
playbook without the override to disable registration:

```bash
sops exec-env ansible/secrets.sops.yml \
  'ansible-playbook ansible/playbooks/vaultwarden.yml --limit rg-identity01'
```

## Initial SOPS Setup

This is required only when establishing a new recovery identity. Generate a
dedicated age identity on the administrator workstation:

```bash
mkdir -p "$HOME/.config/sops/age"
chmod 700 "$HOME/.config/sops/age"
age-keygen -o "$HOME/.config/sops/age/keys.txt"
chmod 600 "$HOME/.config/sops/age/keys.txt"
age-keygen -y "$HOME/.config/sops/age/keys.txt"
```

Save `keys.txt` in Bitwarden. Put the public `age1...` recipient in `.sops.yaml`.
Only the public recipient belongs in Git.

Create the encrypted secrets file and edit its values through SOPS:

```bash
sops encrypt \
  --filename-override ansible/secrets.sops.yml \
  ansible/secrets.example.yml > ansible/secrets.sops.yml
sops ansible/secrets.sops.yml
```

Commit `.sops.yaml` and `ansible/secrets.sops.yml`. Confirm with `git diff` that
none of the secret values appear in plaintext before pushing.
