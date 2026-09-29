# Security policy

Maintainer and triage owner: [Spunky Tensor](https://github.com/spunkytensor).
Only the current `main` configuration is maintained; there are no separately
supported historical release lines or project-published container images.
Update to current source and review upstream advisories before deployment.

Do not put vulnerabilities, credentials, prompts, or private model data in public
issues. If GitHub offers **Report a vulnerability** on this repository's Security
tab, use that private route. GitHub's API reported private reporting disabled on
2026-09-29; this rollout does not change settings. If unavailable, ask the maintainer for a private contact via a public
issue containing no vulnerability details. A verified private route remains an
administrative adoption requirement; this file does not enable one.

The stack is intended for trusted users on a local NVIDIA host, not anonymous
public hosting. Preserve loopback bindings, authentication, offline model mounts,
and the documented shared-terminal trust boundary.

High/Critical vulnerabilities (including unfixed ones) fail security checks.
The maintainer must record an owner and remediation date for findings based on
exposure and exploitability. Revoke leaked credentials immediately. Exceptions
require package/version/finding scope, evidence, owner, reviewer, expiry, and a
tracking reference; no scanner suppressions or VEX exceptions are enabled.

See [coverage and outstanding requirements](docs/security-baseline.md).
