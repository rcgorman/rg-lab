# CIS Level 1 Findings and Exceptions

The bootc image applies the AlmaLinux 10 CIS Level 1 Server remediation during
every build. CI compares every remaining `fail`, `error`, or `unknown` result to
`bootc/cis-expected-findings.txt` and fails when that exact set changes. Both the
HTML report and machine-readable XCCDF results are build artifacts.

The baseline was taken from successful workflow run `37658748951` on
2026-10-07. A matching baseline is not proof that a booted host is compliant;
some runtime-only checks cannot be evaluated in a container build.

## Reviewed Failures

### `ensure_root_password_configured`

- Status: accepted image-build exception.
- Reason: no reusable root password is baked into the image. Human account
  credentials are applied later from SOPS.
- Compensating controls: root SSH login is disabled; SSH is key-only; the
  bootstrap `ansible` password is locked; administrative access is auditable
  through named accounts.
- Revisit when: the console recovery-account policy changes.

### `sshd_limit_user_access`

- Status: temporary exception pending a booted-host policy test.
- Reason: the image does not currently set `AllowUsers` or `AllowGroups` because
  final human identities are applied by Ansible after first boot.
- Compensating controls: root SSH is disabled, password authentication is
  disabled, firewalld permits only the managed baseline services, and SSH keys
  are explicitly managed.
- Planned resolution: validate `AllowGroups wheel` on a disposable VM, including
  first-boot Ansible access, before enforcing it in the image.

## Container-Build Evaluation Errors

The other 24 baseline entries are `error` results for systemd service state and
runtime sysctl checks. The image build is not a booted systemd host, so these are
tracked as scan-environment limitations rather than accepted security
exceptions. The exact rule IDs are versioned in
`bootc/cis-expected-findings.txt`.

Run a CIS scan on a disposable booted VM after major AlmaLinux, SCAP-content, or
bootc changes. Any booted-host failure needs its own entry here with a reason,
owner, compensating control, and review trigger.

## Updating the Baseline

1. Download both CIS artifacts from the failed image workflow.
2. Determine whether each difference is a remediation improvement, a scanner
   change, a real regression, or a justified exception.
3. Fix regressions before changing the baseline.
4. Update this document and `bootc/cis-expected-findings.txt` together.
5. Rerun the workflow and retain the reviewed artifact.
