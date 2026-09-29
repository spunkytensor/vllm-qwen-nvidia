# Security baseline adoption and coverage

Owner: Spunky Tensor. Supported source: current `main`. Platform: Linux amd64.
Baseline: [`69b5f260fb4358acb0e2f7b2a96254ad9cc2322c`](https://github.com/spunkytensor/.github/commit/69b5f260fb4358acb0e2f7b2a96254ad9cc2322c).
This is partial adoption, not a compliance certification.

## Checks and inventory

`Spunky Tensor security` runs on PRs, main pushes, manual invocation, and nightly
at **09:39 UTC** (01:39 PST / 02:39 PDT). Tokens are read-only and actions are
commit-pinned. No images are published, GPU workloads started, or host model
caches downloaded. There was no previous security scanner to replace.

| Subject | Coverage | Boundary |
| --- | --- | --- |
| Shipped source wrappers/configuration | Trivy secret and misconfiguration scan; PR dependency review | No lockfile/installed package tree: a source vulnerability SBOM would be empty and is deliberately not used |
| All three upstream Dockerfile default images | Resolve each current tag's Linux amd64 manifest digest; shared pinned Trivy vulnerability scan and SPDX/CycloneDX SBOMs | Upstream components only, not the final derivatives or historical deployed images; downloaded image layers may contain upstream-bundled assets |
| Built Open Terminal derivative | Build without starting services; scan installed OS/language packages; both SBOMs, image config digest, source commit, timestamp and candidate license table | Includes added nodejs/npm; verifies these appear in detected inventory; not a published manifest digest or release attestation |
| Built vLLM and Open WebUI derivatives | Dockerfile configuration checks only beyond their scanned upstream bases | Full build/installed-package reconciliation remains pending, particularly vLLM's added FlashInfer/CUTLASS and apt dependencies |
| Model weights/tokenizers/configs | Explicit inventory in notices; separate host download | No weight download, content scan, revision attestation, or legal approval |

The shared job scans public immutable image references, rejects empty inventories,
retains all severities, and fails on High/Critical including unfixed findings.
The local built-image job follows that policy with no ignores/VEX. Source checks
also gate High/Critical secrets and configuration findings. Tool, registry, or
database failures are failures, never clean results. Review unsupported package
ecosystems, undetected assets, and end-of-life OS versions even after green scans.

## SBOM downloads and attribution

Download `security-upstream-*-amd64` and `security-built-terminal-amd64` from
[security workflow runs](https://github.com/spunkytensor/vllm-qwen-nvidia/actions/workflows/public-repo-security.yml).
They contain `sbom.spdx.json`, `sbom.cdx.json`, `trivy.json`, tool version,
subject identity and checksums, when generation succeeds. Resolution evidence
maps mutable upstream tags to exact platform digests. Artifacts expire after
30 days and are diagnostics, **not durable release evidence**. Partial uploads
after failures are not successful scans. Last successful nightly scan must be
checked in Actions; no nightly run exists until adoption reaches the default branch.

[THIRD_PARTY_NOTICES.txt](../THIRD_PARTY_NOTICES.txt) separates source, upstream
images, downloaded models, and external services. Preserve upstream license and
NOTICE files. Candidate license metadata is not reviewed attribution: collect
actual license texts, applicable Apache NOTICE content, copyleft/source-offer
obligations, and branding requirements before redistributing images. ORT/ScanCode
integration and legal review remain pending. The wrapper's Apache-2.0 is unchanged.
The wrapper license and inventory are copied to
`/usr/share/doc/vllm-qwen-nvidia/` in all three derivative Dockerfiles without
removing upstream notices or changing runtime users, entrypoints, or packages.

Initial local verification on 2026-09-29 used Trivy 0.74.0 against the actual
Open Terminal Linux amd64 upstream digest: 217 detected packages and 209
High/Critical findings. Both SBOM formats were generated and the gate rejected
the findings. This is not a clean security bill; investigate the retained reports
and update affected upstreams without silently weakening thresholds. The source
scan found three Dockerfiles and no High/Critical configuration/secret findings.

## Outstanding requirements (maintainer owned)

- Verify private vulnerability reporting; enable dependency graph, Dependabot
  alerts/updates, secret scanning/push protection, branch required reviews/checks,
  code-owner enforcement, 2FA and periodic access review. No settings changed by
  this adoption. CodeQL does not analyze this shell/Docker-only project.
- Provide capacity-tested CPU-only builds/scans of the complete vLLM and WebUI
  images. Large CUDA layers can exceed hosted-runner disk/time budgets. Do not
  substitute a base-image scan for the missing derived-package coverage.
- The central reusable workflow needs a reviewed local OCI archive/build-input
  interface to share the same scan/gate/attribution logic with derivative builds;
  it currently accepts only source or public registry image digests. The terminal
  job is a scoped adapter, not permission to publish PR images. Central source
  secret/configuration scanning and attribution generation are also absent.
- Reconcile SBOMs against installed package metadata, bundled native libraries,
  fonts, JavaScript assets and build outputs, not only nonempty package counts.
  Confirm logo provenance and exact upstream/model license obligations.
- Tags and apt resolution are mutable; scans record current identities, not all
  operator overrides or existing installations. No project images/releases are
  published today. Before publishing any, add per-release/platform digest
  inventory, nightly historical release scans, durable SBOMs/notices/checksums,
  and digest-bound provenance/attestations. No SLSA level is claimed.
- Record finding owners/remediation dates and establish central last-success
  reporting with alerts after 36 hours. GitHub may delay/drop schedules or disable
  them after 60 days of inactivity. Cron alone is not freshness monitoring.
