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

## Proxmox API Token

Create a Proxmox API token for OpenTofu and pass it as:

```hcl
proxmox_api_token = "terraform@pve!rg-lab=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
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

## Notes

The VM module follows the same broad pattern as the inspiration repo: `q35`, `ovmf`, an EFI disk, a boot disk created from the imported bootc image, static cloud-init networking, and an `ansible` user with SSH keys.
