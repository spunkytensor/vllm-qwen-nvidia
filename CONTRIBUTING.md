# Contributing

Thanks for taking the time to contribute. This is a small hobby project, so
expectations are kept light, but a few notes will make collaboration smoother.

## Project status

This repository is maintained on a best-effort basis in the maintainer's spare
time. Issues and pull requests may not receive immediate attention, and there
is no guaranteed support, SLA, or roadmap. The project is provided "as is" —
see the disclaimer in `README.md` and the warranty section of `LICENSE`.

## Reporting issues

Before opening an issue:

1. Check existing issues to avoid duplicates.
2. Confirm the problem reproduces against the current `main` branch with the
   default `.env.example` settings.
3. Include enough context for someone else to diagnose:
   - GPU model and driver version (`nvidia-smi` header is fine)
   - Docker / Compose version
   - Exact `.env` overrides you used (redact tokens)
   - Relevant container logs (`docker compose logs vllm`)
   - The `vllm serve` command line printed at startup

For suspected vLLM bugs, please also report upstream at
<https://github.com/vllm-project/vllm/issues> — most engine-level issues are
not specific to this wrapper.

## Submitting changes

1. Fork the repository and create a topic branch off `main`.
2. Keep changes focused. Small, single-purpose pull requests are easier to
   review than large ones.
3. Update `README.md` and `.env.example` if your change affects user-visible
   defaults or workflow.
4. Verify the container still builds and starts:

   ```bash
   docker compose build
   docker compose up -d
   docker compose logs -f vllm
   ```

5. Open a pull request describing what changed and why. Link any relevant
   issues.

## Style

- Shell scripts: `bash` with `set -euo pipefail`. Keep them small and
  parameterizable via environment variables.
- Dockerfile: prefer extending the upstream `vllm/vllm-openai` image rather
  than rebuilding vLLM from source.
- Markdown: wrap prose at a comfortable width; fenced code blocks for any
  command the reader is expected to run.

## Licensing of contributions

By submitting a contribution (pull request, patch, or any other form), you
agree that your contribution is licensed under the terms of the Apache
License, Version 2.0, the same license that covers this project (see
`LICENSE`). You also represent that you have the right to submit the
contribution under that license.

No separate Contributor License Agreement (CLA) is required.

## Code of conduct

Be civil. Disagree with ideas, not people. Maintainers reserve the right to
close or remove discussion that is harassing, off-topic, or otherwise
unproductive.
