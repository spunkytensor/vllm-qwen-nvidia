# Qwen3.6 NVFP4 vLLM Stack

![Qwen3.6 NVFP4 vLLM Stack logo](logo.jpg)

This repository runs either of two Unsloth NVFP4 Qwen3.6 checkpoints on one
NVIDIA GPU and exposes them through vLLM's OpenAI-compatible API. The default
Docker Compose stack runs only vLLM. Connect with an OpenAI-compatible client
or the optional standalone OpenCode configuration; no web interface, search
provider, embedding service, or terminal server is bundled.

This project is tuned and measured on one NVIDIA RTX 5090 with 32 GB of
VRAM. It has no SLA or warranty. The wrapper is open source under the
[Apache License 2.0](LICENSE); contributions are welcome through the workflow in
[CONTRIBUTING.md](CONTRIBUTING.md).

## How it works

```text
OpenAI client / OpenCode → vLLM API :8000 → Qwen3.6 NVFP4 on RTX 5090
```

vLLM receives the NVIDIA device and a read-only host checkpoint cache. Its API
requires a Bearer token and binds to host loopback by default.

## Requirements

- NVIDIA driver 580 or newer; this host uses the open-kernel driver required
  for Blackwell.
- Docker Engine with the Compose plugin.
- NVIDIA Container Toolkit configured for Docker.
- Enough disk for the selected checkpoint, the vLLM image, and persistent caches.

The pinned vLLM image uses CUDA 13. A driver that is too old can fail with
`Error 804: forward compatibility was attempted on non supported HW`. Verify
the base image and GPU runtime before starting the full stack:

```bash
docker run --rm --runtime nvidia --gpus all \
  vllm/vllm-openai:v0.25.1 nvidia-smi
```

## Supported platform

The measured settings and smoke tests target Linux x86_64, Docker Compose, and
one RTX 5090. Other recent NVIDIA GPUs may work, but context capacity and memory
settings must be measured again. macOS and Windows cannot run this CUDA stack
as configured.

## Install

Clone the repository and create the local configuration:

```bash
git clone https://github.com/spunkytensor/vllm-qwen-nvidia.git
cd vllm-qwen-nvidia
cp .env.example .env
```

Generate a secret and paste it into `.env` as `VLLM_API_KEY`:

```bash
openssl rand -hex 32
```

Download the selected model with the host Hugging Face CLI (installed directly
or invoked ephemerally through `uvx`), then start vLLM:

```bash
./scripts/download-model.sh
./scripts/compose.sh up -d --build
./scripts/compose.sh logs -f vllm
```

The stack never downloads model assets. `download-model.sh` reads
`MODEL_PRESET` from the environment or `.env`, defaults to
`Qwen3.6-35B-A3B`, and stores the generation checkpoint in
`${HF_CACHE_PATH:-$HOME/.cache/huggingface}`. Set `HF_TOKEN` in the host shell
when the Hugging Face CLI needs one; the token is not passed into vLLM. The
Compose wrapper detects the invoking host UID, checks for the selected
checkpoint, and mounts the cache read-only. vLLM runs in Hugging Face offline
mode and fails instead of downloading missing files.

Model initialization can take several minutes. The vLLM API is available at
<http://localhost:8000/v1> and requires `VLLM_API_KEY` as a Bearer token. Do not
change the loopback bind address without an appropriate firewall or
authenticated TLS reverse proxy. For the API examples below, export
`VLLM_API_KEY` in your client shell with the same value as the server's `.env`;
the shell does not automatically load that file.

## Configuration

The top-level `.env` is the operator interface. These are the primary settings:

| Variable | Default | Purpose |
|---|---:|---|
| `MODEL_PRESET` | `Qwen3.6-35B-A3B` | Select the complete validated vLLM profile. |
| `HOST_PORT` | `8000` | Publish the vLLM API on this host port. |
| `VLLM_BIND_ADDRESS` | `127.0.0.1` | Host address on which to publish vLLM. |
| `VLLM_SHM_SIZE` | `8gb` | Size of vLLM's private shared-memory filesystem. |
| `VLLM_PIDS_LIMIT` | `1024` | Container process/thread ceiling; increase only if the GPU workload requires it. |
| `VLLM_API_KEY` | none | Authenticate vLLM clients; replace the example value. |
| `HF_CACHE_PATH` | `$HOME/.cache/huggingface` | Host cache populated before the stack starts and mounted read-only into vLLM. |

Safe vLLM experiment overrides are also available: `MAX_MODEL_LEN`,
`GPU_MEMORY_UTILIZATION`, `MAX_NUM_SEQS`, and `MAX_NUM_BATCHED_TOKENS`. Invalid
numeric values fail before vLLM starts.

### Model switching

The accepted presets are exactly `Qwen3.6-35B-A3B` and `Qwen3.6-27B`. Change
`MODEL_PRESET` in `.env`, then recreate vLLM:

```bash
./scripts/download-model.sh
./scripts/compose.sh up -d --force-recreate vllm
```

Select the matching model name in your client. Verify the active API identity:

```bash
curl -s -H "Authorization: Bearer $VLLM_API_KEY" \
  http://localhost:8000/v1/models | jq '.data[].id'
```

## Model and runtime defaults

| Preset | Checkpoint | Context | Sequences | GPU utilization | MTP |
|---|---|---:|---:|---:|---:|
| `Qwen3.6-35B-A3B` | `unsloth/Qwen3.6-35B-A3B-NVFP4` | 185,000 | 1 | 0.93 | 2 |
| `Qwen3.6-27B` | `unsloth/Qwen3.6-27B-NVFP4` | 102,400 | 1 | 0.90 | 2 |

### Why the Unsloth checkpoints

Both distributions quantize the same Qwen base models; the choice here is about
deployment format and kernels. The Unsloth checkpoints use the
`compressed-tensors` NVFP4 layout that follows vLLM's native CuTe DSL, CUTLASS,
and FlashInfer paths on this RTX 5090 stack. By contrast, NVIDIA's checkpoints
use ModelOpt packaging and document ModelOpt/Marlin-oriented serving paths.
Unsloth's published comparison reports similar accuracy with higher throughput,
so these presets use its weights while retaining NVIDIA's checkpoints as valid
alternatives. See the [Unsloth model card](https://huggingface.co/unsloth/Qwen3.6-27B-NVFP4)
and [NVIDIA model card](https://huggingface.co/nvidia/Qwen3.6-35B-A3B-NVFP4)
for their respective recipes and benchmarks.

Both presets use vLLM 0.25.1, FP8 KV cache, chunked prefill, two-token MTP
speculation, Qwen reasoning and tool parsers, and text-plus-image input. The
checkpoint metadata selects NVFP4 automatically, so the launcher does not force
a quantization or MoE backend. In particular, it does not force Marlin;
Unsloth recommends the native CuTe DSL, CUTLASS, and FlashInfer path for these
checkpoints.

The shared launcher applies:

- `--kv-cache-dtype fp8`
- `--max-num-batched-tokens 8192`
- `--no-enable-prefix-caching` and `--enable-chunked-prefill`
- `--reasoning-parser qwen3`
- automatic tool choice with `--tool-call-parser qwen3_coder`
- one image and no video per prompt
- `--speculative-config {"method":"mtp","num_speculative_tokens":2}`

It intentionally does not use `--trust-remote-code`, a forced quantization
backend, YaRN, or the optional 1,010,000-token extension.

### Measured context limits

On the tested RTX 5090, 35B-A3B with MTP at 0.93 left 2.15 GiB for KV cache.
vLLM estimated a maximum length of 185,136 tokens, so the preset uses 185,000.
Disabling MTP permits the native 262,144-token context, but this profile
prioritizes speculative decoding.

The 27B preset was measured with the same pinned stack, FP8 KV, MTP=2, and one
sequence:

- `--max-model-len 103424` initialized successfully.
- vLLM reported a GPU KV-cache capacity of 106,219 tokens.
- The preset uses 102,400, leaving 1,024 tokens below the verified startup
  point and 3,819 below the reported allocator capacity.

Hybrid attention makes capacity nonlinear. Treat these results as specific to
the exact driver, GPU, vLLM version, and flags; recheck the `GPU KV cache size`
startup line after changing any of them.

## Privacy, security, and costs

Inference runs on the local vLLM host. No hosted search provider or chat store
is bundled; any external client controls its own storage and integrations.
Model downloads require network access on the host before startup.

Set `VLLM_API_KEY` before use, never commit `.env`, and do not expose port 8000
directly to an untrusted network. vLLM's API key does
not protect every non-OpenAI endpoint, so loopback binding or a firewall remains
part of the security boundary. This stack does not provide TLS, rate limiting,
per-user authentication, or a hardened public ingress.

### Runtime hardening

- The wrapper refuses `up` and `start` from host UID 0. The container launcher
  independently refuses UID 0, including when Compose is bypassed. Use a
  non-root account with Docker access; root can still stop the old stack.
- Image inputs must use inline base64 `data:` URLs instead of remote URLs.
  The media domain allowlist contains only the reserved hostname
  `invalid.invalid`; an empty list in vLLM would allow every hostname. Do not
  map this reserved name to a real destination in DNS or `/etc/hosts`.
  Media redirects are disabled, and local-file media access stays disabled.
  This reduces server-side request forgery exposure, but it is **not** a
  general network egress firewall or a guarantee that image decoders are safe.
- `/docs`, `/redoc`, and `/openapi.json` are disabled. This removes unnecessary
  endpoints, not the need for authentication and network isolation.
- Compose caps the total number of processes and threads at 1,024 by default.
  If cold-cache GPU initialization hits this ceiling, measure usage and raise
  `VLLM_PIDS_LIMIT` rather than disabling the limit. This does not cap memory
  usage or substitute for request limits at an ingress proxy.

Keep the deployment host's kernel, NVIDIA driver, NVIDIA Container Toolkit,
and Docker patched. Containers share the host kernel; updating packages in
the image does not patch that kernel. Offline Hugging Face settings are not a
network firewall: enforce outbound restrictions on the host if required.

### Vulnerability scanning

`.github/workflows/public-repo-security.yml` runs the shared Spunky Tensor
Trivy baseline on pull requests, pushes to `main`, and nightly. It scans the
Python pins in `docker/vllm/requirements.txt` and builds and scans the vLLM
image, failing on any High or Critical finding, including findings that
upstream has not fixed yet. Reports and SBOMs are kept as workflow artifacts.

The base image is pinned by digest and updated by Dependabot. Each build also
applies the distribution's security updates and the Python overrides in
`docker/vllm/requirements.txt`; remove an override once the base image ships a
fixed version.

The October 14, 2026 scan of the vLLM-only image attributed all 204 High/Critical
findings to `linux-libc-dev` (development headers from Ubuntu's `linux` source
package), not to scanned Python or Rust packages. This does not establish
host-kernel exploitability or absence of other vulnerabilities. Headers and
compilers are retained because cold-cache GPU compilation may require them;
runtime hardening neither patches these reported CVEs nor suppresses the gate.
Removing build dependencies requires testing both presets with empty runtime
caches on a compatible GPU first.

## Persistent data

Compose preserves:

- `${HF_CACHE_PATH:-$HOME/.cache/huggingface}` for generation checkpoints
  downloaded and owned by the host user; vLLM mounts it read-only.
- `vllm-runtime-cache` for vLLM compilation and autotuning artifacts.

vLLM runs as the invoking host UID (use a non-root host account), with all Linux
capabilities dropped, privilege escalation disabled, and a read-only root
filesystem. Only the runtime cache volume and ephemeral `/tmp` filesystem are writable.
The Docker daemon remains the normal system (rootful) daemon; Docker Rootless
mode is not required or configured by this project.

### Migrating an existing installation

Open WebUI and Open Terminal have been removed due to CVE concerns, along with
their search and embedding integrations. Updating the Compose file alone does
not stop existing containers. After updating the checkout, use the same Compose
project name as the old installation and remove its orphaned containers:

```bash
./scripts/compose.sh down --remove-orphans
./scripts/compose.sh up -d --build --remove-orphans
./scripts/compose.sh ps
```

Only vLLM should remain. This briefly stops vLLM but preserves named volumes;
do not add `--volumes`. Confirm that no old UI or terminal containers remain
with `docker ps -a`, including any launched outside this Compose project.

Remove obsolete `OPEN_WEBUI_*`, `WEBUI_SECRET_KEY`, `OPEN_TERMINAL_*`,
`TAVILY_API_KEY`, and `EMBEDDING_CACHE_PATH` settings from `.env` and your shell.
Revoke the unused Tavily credential at the provider. Rotate `VLLM_API_KEY` if
it was shared with the removed applications, and update your clients.

The old `open-webui-data`, `open-webui-static`, and `open-terminal-home` volumes
are no longer mounted. Back up any data you need before explicitly deleting
them with `docker volume rm`; deletion is permanent. Compose normally prefixes
these names with the checkout directory name, so identify the actual names
with `docker volume ls`. Old application images and the host embedding cache
are also unused and can be removed after confirming they are not needed by
another installation. No cleanup command here deletes them automatically.

The existing host Hugging Face generation cache and `vllm-runtime-cache` remain
in use and need no migration. If the host cache lives outside
`$HOME/.cache/huggingface`, export an absolute `HF_CACHE_PATH` before running
either helper script.

## Troubleshooting

Inspect service state and health first:

```bash
./scripts/compose.sh ps
./scripts/compose.sh logs --tail=200 vllm
```

If the API is unavailable, vLLM may still be loading its model or may have
failed its health check. Follow `./scripts/compose.sh logs -f vllm` and look
for the final API startup message.

A maximum-sequence-length error means the configured context does not fit the
available KV cache. The `GPU KV cache size` line is authoritative for that
launch. For initialization OOMs, check for other GPU users:

```bash
docker ps --format '{{.Names}}\t{{.Status}}'
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
```

## Testing

Test the stack in layers so failures remain easy to locate.

### Layer 1 — configuration

```bash
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck --shell=bash --exclude=SC2016 scripts/*.sh
python3 -B -m unittest discover -s tests -v
jq empty opencode/opencode.json
./scripts/compose.sh config --quiet
./scripts/compose.sh config --services  # must print only vllm
git diff --check
```

Run the Compose check once with each supported `MODEL_PRESET`.

The build performs package installation as root, but the final image declares
a non-root `USER`. Verify the image metadata and rendered Compose user:

```bash
docker image inspect qwen3.6-nvfp4-vllm-local:latest \
  --format '{{.RepoTags}} user={{.Config.User}}'
./scripts/compose.sh config | grep -A1 'user:'
```

### Layer 2 — service health

```bash
./scripts/compose.sh up -d --build
./scripts/compose.sh ps
curl -fsS http://localhost:8000/health
curl -s -H "Authorization: Bearer $VLLM_API_KEY" \
  http://localhost:8000/v1/models | jq '.data[].id'
```

vLLM should become healthy and appear in `nvidia-smi`. Compose should publish
only the configured vLLM port, bound to loopback by default.

Confirm the runtime security boundary:

```bash
./scripts/compose.sh exec vllm sh -c \
  'test "$(id -u)" -ne 0 && grep -E "^(CapEff|CapPrm):[[:space:]]+0+$|^NoNewPrivs:[[:space:]]+1$" /proc/1/status'
! ./scripts/compose.sh exec vllm sh -c 'touch /non-root-write-test'
```

### Layer 3 — integration smoke tests

Generate a response using the active model identity:

```bash
model=$(curl -fsS -H "Authorization: Bearer $VLLM_API_KEY" \
  http://localhost:8000/v1/models | jq -r '.data[0].id')
jq -n --arg model "$model" \
  '{model: $model, messages: [{role: "user", content: "Say hello."}], max_tokens: 128}' \
  | curl -fsS http://localhost:8000/v1/chat/completions \
      -H "Authorization: Bearer $VLLM_API_KEY" \
      -H 'Content-Type: application/json' --data-binary @- | jq .
```

Confirm an unauthenticated request to `/v1/models` returns HTTP 401. Restart
vLLM and repeat the authenticated request to verify offline startup and cache
reuse. Repeat with each supported preset on a compatible GPU host.

For the hardening policy, also verify on that host:

- `/docs`, `/redoc`, and `/openapi.json` return 404, even with a valid API key.
- A valid inline base64 image still works; image URLs targeting loopback,
  cloud metadata addresses, and public websites are rejected.
- `docker inspect qwen3.6-nvfp4-vllm --format '{{.HostConfig.PidsLimit}}'`
  reports the configured limit. Test startup with a fresh runtime cache and
  watch for process/thread exhaustion before adopting a lower ceiling.

## OpenCode

The standalone [OpenCode configuration](opencode/opencode.json) defines both API
model names with their measured context limits. It is an optional external
client, not a Compose service, and reads its API key from the shell:

```bash
cp opencode/opencode.json /path/to/project/.opencode.json
export VLLM_API_KEY='<the VLLM_API_KEY from the server .env>'
opencode --dir /path/to/project
```

The 35B-A3B model is the static default. Choose the 27B entry through OpenCode's
model picker or with `--model vllm/Qwen3.6-27B`. The selected name must match the
model currently served by vLLM.

## Upstream documentation and credits

- [vLLM](https://docs.vllm.ai/) provides the OpenAI-compatible inference server.
- [Qwen](https://qwen.readthedocs.io/) publishes the model family and tooling
  documentation.
- [Unsloth](https://docs.unsloth.ai/) publishes the NVFP4 checkpoints and related
  deployment guidance.

This project is not affiliated with or endorsed by those projects, vendors, or
model authors.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md)
before opening a pull request so the local checks, configuration documentation,
and license expectations remain consistent.

## License

This wrapper is licensed under the [Apache License 2.0](LICENSE). It does not
redistribute container images or model weights; those remain subject to their
upstream licenses and terms.
