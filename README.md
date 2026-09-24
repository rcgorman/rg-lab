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

A workstation can recreate and configure any single VM directly from this
repository. See [`RECOVERY.md`](RECOVERY.md) for the recovery kit and exact
rebuild sequence.

Application version tags live in
[`container_versions.yml`](ansible/inventory/group_vars/all/container_versions.yml).
Each application role keeps its Quadlets in native-format `templates/` files.
The image provides the `ansible` bootstrap account; Ansible owns human accounts.

## Validation

The `Validate configuration` GitHub Actions workflow runs on pull requests,
pushes to `main`, and manual dispatch. It checks YAML and Ansible lint, playbook
syntax, Quadlet templates, OpenTofu formatting/validation, and mock-provider tests.
It needs no SOPS key, Proxmox credentials, or host SSH keys, and never deploys.
Backups and published-port policy are separate work, not changed by validation.

To run the same checks locally with the tools installed:

```bash
yamllint --strict .
ansible-lint --offline ansible/playbooks ansible/roles ansible/tests
ansible-playbook ansible/playbooks/site.yml --syntax-check
ansible-playbook ansible/tests/quadlets.yml
tofu -chdir=terraform fmt -check -recursive
tofu -chdir=terraform validate
tofu -chdir=terraform test
```

## Image Updates

GitHub Actions builds on bootc changes, manual dispatch, and every Monday at
06:23 UTC. Each uncached build pulls the base image and runs `dnf upgrade` inside
the build, then applies the configured hardening. This does not update or reboot
running VMs. Use `ansible/playbooks/bootc_upgrade.yml` for a deliberate rollout.

Images receive `latest`, `sha-<commit>`, and unique `build-<run-id>-<attempt>` tags.
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
