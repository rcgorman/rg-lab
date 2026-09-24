# OpenTofu / Proxmox

This layer provisions Proxmox VMs from an imported bootc `qcow2` image.

Keep this layer focused on infrastructure facts:

- VM name and ID
- CPU and memory
- disk size
- network and VLAN
- static IP or cloud-init network config
- stable primary-NIC MAC address
- SSH key injection for the `ansible` user

Application containers should not be defined here. They belong in Ansible roles as Podman quadlets.

## Assumed Flow

1. Build and push the bootc image with GitHub Actions.
2. Convert the image to `qcow2`.
3. Upload/import the disk into Proxmox storage so it has a file ID such as `local:import/rg-lab-alma10_2-bootc.qcow2`.
4. Use OpenTofu to create workload VMs from that image.
5. Run Ansible from the administrator workstation to enroll NetBird and deploy Podman quadlets.

The imported image can live on `local`, while created VM disks can live on another datastore. `main.tf` defines the VMs directly using the provider's `import_from` disk attribute:

```hcl
image_id     = "local:import/rg-lab-alma10_2-bootc.qcow2"
datastore_id = "storage"
```

## Network Ownership

Proxmox cloud-init is the only owner of VM hostnames, static addresses, gateways,
DNS servers, and SSH key injection. The bootc image supplies cloud-init but
contains no platform-specific datasource or per-host network profile. Ansible
does not create or modify NetworkManager connections.

Every VM has a stable, unique MAC address in `tofu.tfvars`. Keep those MACs when
recreating a VM. Validation rejects duplicate VM IDs, IPs, and MACs before apply.

The provider does not wait for QEMU guest-agent to report an address because the
address is already declared in OpenTofu and agent reporting can lag during first
boot. This avoids treating a slow guest agent as a failed VM creation. Verify a
new VM from its console or over SSH with:

```bash
cloud-init status --long
nmcli connection show --active
ip -4 address show dev eth0
ip route
```

The active host connection should be `cloud-init eth0`; there should be no
`lab-static-eth0` profile and no `99-disable-network-config.cfg` file.

For Proxmox `local` directory storage, the import file should exist here:

```text
/var/lib/vz/import/rg-lab-alma10_2-bootc.qcow2
```

Check it with:

```bash
pvesm list local --content import
```

The bootc image creates the `ansible` account; Proxmox cloud-init supplies its keys:

```hcl
ssh_public_keys = [
  "ssh-ed25519 AAAA..."
]
```

Ansible creates the `ryan` account and sets its password hash and SSH key. Human
identities are not baked into the image or managed through Terraform, so existing
VMs can be updated without replacing them.

## Existing State

The former single-use VM module has been folded into `main.tf`. Its `moved`
blocks preserve the existing `identity` and `data` instances. Keep these blocks
so an older state backup can still be used. This refactor should not recreate VMs.
Before applying, back up state outside Git and inspect `tofu plan`. Expect moves
from `module.vm["identity"].proxmox_virtual_environment_vm.this` to
`proxmox_virtual_environment_vm.vm["identity"]`, and the equivalent for `data`.
Stop if the plan unexpectedly destroys or replaces a VM or disk. Do not import
the same VMs again or delete them manually for this refactor.

Local validation (OpenTofu 1.11 used for the mock-provider tests):

```bash
tofu fmt -check -recursive
tofu validate
tofu test
```

`tofu test` uses a mock provider and does not contact Proxmox or alter live state.

## API TLS

Certificate verification is the default. The current direct endpoint
`https://10.6.13.10:8006/` still needs the explicit `proxmox_insecure = true`
exception in your local variables because it uses a self-signed certificate.
HAProxy's trusted frontend certificate does not apply to this direct connection.
Install/trust an appropriate Proxmox certificate, or verify that the API works
through the trusted HAProxy endpoint, before changing this exception to `false`.


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

The VM resource uses `q35`, `ovmf`, an EFI disk, a boot disk created from the imported bootc image, and static cloud-init networking.

Cloud-init package upgrades are disabled in OpenTofu because bootc hosts should update with `bootc upgrade`, not `dnf upgrade` during first boot.
