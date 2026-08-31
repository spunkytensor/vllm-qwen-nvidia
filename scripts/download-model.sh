#!/usr/bin/env bash

set -euo pipefail

# .env is read by relative path, so anchor to the checkout regardless of where
# the caller invoked this script from.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=scripts/env-preset.sh
source scripts/env-preset.sh

if command -v hf >/dev/null 2>&1; then
  hf_command=(hf)
elif command -v uvx >/dev/null 2>&1; then
  hf_command=(uvx --from huggingface-hub hf)
else
  printf 'The Hugging Face CLI is required. Install it with `pipx install huggingface-hub`, or install uv.\n' >&2
  exit 2
fi

preset="$(resolve_model_preset)"

case "$preset" in
  Qwen3.8-27B)
    model_id="unsloth/Qwen3.8-27B-NVFP4"
    ;;
  *)
    printf 'Unsupported MODEL_PRESET=%q. Choose Qwen3.8-27B.\n' "$preset" >&2
    exit 2
    ;;
esac

cache_path="${HF_CACHE_PATH:-${HOME}/.cache/huggingface}"
if [[ "$cache_path" != /* ]]; then
  printf 'HF_CACHE_PATH must be absolute; got %q.\n' "$cache_path" >&2
  exit 2
fi
embedding_cache_path="${EMBEDDING_CACHE_PATH:-${HOME}/.cache/open-webui/embedding}"
if [[ "$embedding_cache_path" != /* ]]; then
  printf 'EMBEDDING_CACHE_PATH must be absolute; got %q.\n' "$embedding_cache_path" >&2
  exit 2
fi

mkdir -p "$cache_path" "$embedding_cache_path"
printf 'Downloading %s into %s\n' "$model_id" "$cache_path"
env HF_HOME="$cache_path" "${hf_command[@]}" download "$model_id"
printf 'Downloading Qwen/Qwen3-Embedding-0.6B into %s\n' "$embedding_cache_path"
"${hf_command[@]}" download --cache-dir "$embedding_cache_path" Qwen/Qwen3-Embedding-0.6B
