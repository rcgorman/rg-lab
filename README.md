# rg-lab

My homelab infrastructure built around:

- `bootc` for the VM operating system image
- `Ansible` from an administrator workstation for host and service configuration
- `OpenTofu` for VM provisioning
- `SOPS` with `age` for encrypted secrets in Git

## Current Direction

The VM base image:

- AlmaLinux 10 bootc base
- cloud-init and qemu-guest-agent for VM provisioning
- firewalld, chrony, SELinux enforcing defaults
- NetBird client installed in the host image

Service deployment should be VM-by-VM:

1. OpenTofu creates or updates a VM from the bootc disk image.
2. SOPS decrypts the required secrets only for the local Ansible process.
3. Ansible configures the host, enrolls NetBird, and calls one role per service.
4. Service roles render Podman quadlets into `/etc/containers/systemd/` and any needed config files in `/srv/quadlet/servicename/`.
5. After the TrueNAS Restic repository is ready, its standalone playbook enables application-aware backups and Restic uploads.

A workstation can recreate and configure any single VM directly from this
repository. See [`RECOVERY.md`](RECOVERY.md) for the recovery kit and exact
rebuild sequence.

Infrastructure configured outside Git is recorded in
[`docs/network.md`](docs/network.md), [`docs/storage.md`](docs/storage.md), and
[`docs/backup.md`](docs/backup.md). Lightweight alerting is specified in
[`docs/monitoring.md`](docs/monitoring.md). Reviewed hardening findings are tracked in
[`docs/CIS-EXCEPTIONS.md`](docs/CIS-EXCEPTIONS.md).

Application version tags live in
[`container_versions.yml`](ansible/inventory/group_vars/all/container_versions.yml).
Each application role keeps its Quadlets in native-format `templates/` files.
The pinned Linux System Roles Podman collection deploys those definitions. The
image provides the `ansible` bootstrap account; Ansible owns human accounts.

## Local Checks

Run these checks locally with the tools installed:

```bash
ansible-galaxy collection install --requirements-file ansible/requirements.yml
yamllint --strict .
ansible-lint --offline ansible/playbooks ansible/roles
ansible-playbook ansible/playbooks/site.yml --syntax-check
ansible-playbook ansible/playbooks/backups.yml --syntax-check
ansible-playbook ansible/playbooks/smoke_tests.yml --syntax-check
tofu -chdir=terraform fmt -check -recursive
tofu -chdir=terraform validate
tofu -chdir=terraform test
```

## Image Updates

GitHub Actions builds on bootc changes, manual dispatch, and every Monday at
06:23 UTC. The workflow uses AlmaLinux `atomic-ci` v13 to build the AMD64 image,
verify its RPM databases, rechunk it with `bootc-base-imagectl`, and publish an
SPDX JSON SBOM as a workflow artifact. The Containerfile still runs `dnf upgrade`
and applies the configured hardening. This does not update or reboot running VMs.
Use `ansible/playbooks/bootc_upgrade.yml` for a deliberate rollout.

`atomic-ci` builds from the repository root. `.containerignore` restricts that
context to `bootc/`; keep it in place so Terraform state, recovery material, and
other workstation files cannot enter the image-build context.

The rechunked image is first published under an internal build tag. A separate
job extracts its CIS report and compares it with the reviewed baseline. Only a
passing digest receives `latest`, `sha-<commit>`, and the unique
`build-<run-id>-<attempt>` tag. Images are not currently signed.

The first upgrade from an image built by the former workflow downloads the full
image because rechunking changes its layer layout. Later upgrades can reuse the
package-oriented layers and should transfer substantially less unchanged data.
Scheduled rebuilds can change `latest` and the commit tag without a Git change;
record the image digest or unique build tag used for a recovery QCOW2. Ensure a
VM tracks the intended update tag with `sudo bootc status` before an upgrade.

The CIS remediation report is published as a build artifact and retained inside
the image at `/usr/share/rg-lab/cis-server-l1.html`. Scanner failures fail the
build; remaining compliance findings are reported. This is not certification
that every CIS control passes on a running host.

SELinux remains enforcing. The lockdown service no longer orders itself before
`sysinit.target` or makes `/etc/selinux/config` immutable. An existing host may
still retain the old immutable flag; inspect with `sudo lsattr /etc/selinux/config`
and remove it with `sudo chattr -i /etc/selinux/config` if present. This does not
disable SELinux.
