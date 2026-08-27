# OpenTofu / Proxmox

This layer provisions Proxmox VMs from an imported bootc `qcow2` image.

Keep this layer focused on infrastructure facts:

- VM name and ID
- CPU and memory
- disk size
- network and VLAN
- static IP or cloud-init network config
- SSH key injection for the `ansible` user

Application containers should not be defined here. They belong in Ansible roles as Podman quadlets.

## Assumed Flow

1. Build and push the bootc image with GitHub Actions.
2. Convert the image to `qcow2`.
3. Upload/import the disk into Proxmox storage so it has a file ID such as `local:import/rg-lab-alma10_2-bootc.qcow2`.
4. Use OpenTofu to create workload VMs from that image.
5. Use Semaphore/Ansible to enroll NetBird and deploy Podman quadlets.

The imported image can live on `local`, while created VM disks can live on a different datastore such as `data`. The VM module imports the image with the provider's `import_from` disk attribute:

```hcl
image_id     = "local:import/rg-lab-alma10_2-bootc.qcow2"
datastore_id = "data"
```

For Proxmox `local` directory storage, the import file should exist here:

```text
/var/lib/vz/import/rg-lab-alma10_2-bootc.qcow2
```

Check it with:

```bash
pvesm list local --content import
```

OpenTofu creates the `ansible` automation account through Proxmox cloud-init:

```hcl
ssh_public_keys = [
  "ssh-ed25519 AAAA..."
]
```

Human admin users are managed by Ansible so existing VMs can be updated without
replacing them.


## Proxmox API Token

Create a Proxmox API token for OpenTofu and pass it as:

```hcl
proxmox_api_token = "terraform@pam!opentofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Do not commit real `*.tfvars` files.

## First Run

Create your real variables file:

```bash
cp tofu.tfvars.example tofu.tfvars
```

Edit `tofu.tfvars`, then run:

```bash
tofu init
tofu plan -var-file=tofu.tfvars
tofu apply -var-file=tofu.tfvars
```

## Provider Check

Make sure OpenTofu has the Proxmox provider installed:

```bash
tofu init
tofu providers
```

Expected provider:

```text
registry.opentofu.org/bpg/proxmox
```

## Proxmox Permission Check

The provider uses both the Proxmox API and SSH:

- API token: `proxmox_api_token`
- SSH user/key: `proxmox_ssh_username` and `proxmox_ssh_private_key_path`

For the first successful apply, keep it simple:

```text
API user/token: terraform@pam!opentofu
Permission path: /
Role: Administrator
Propagate: yes
Privilege separation: disabled, or token ACL explicitly granted
SSH user: root
```

In the Proxmox UI, check:

```text
Datacenter -> Permissions
Datacenter -> Permissions -> API Tokens
```

If privilege separation is enabled for the token, the token itself needs permissions, not just the parent user.

You can test the API token from your workstation:

```bash
curl -k \
  -H 'Authorization: PVEAPIToken=terraform@pam!opentofu=TOKEN_SECRET' \
  https://10.6.13.10:8006/api2/json/version
```

You can test SSH separately:

```bash
ssh -i ~/.ssh/id_ed25519_terraform root@10.6.13.10
```

## Notes

The VM module follows the same broad pattern as the inspiration repo: `q35`, `ovmf`, an EFI disk, a boot disk created from the imported bootc image, static cloud-init networking, and an `ansible` user with SSH keys.

Cloud-init package upgrades are disabled in OpenTofu because bootc hosts should update with `bootc upgrade`, not `dnf upgrade` during first boot.
