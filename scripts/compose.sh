#!/usr/bin/env bash

set -euo pipefail

if (( $# == 0 )); then
  printf 'Usage: %s <docker compose arguments...>\n' "$0" >&2
  exit 2
fi

# docker-compose.yml and .env are read by relative path, so anchor to the
# checkout regardless of where the caller invoked this script from.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=scripts/env-preset.sh
source scripts/env-preset.sh

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

VLLM_UID="$(id -u)"
export VLLM_UID
export HF_CACHE_PATH="$cache_path"
export EMBEDDING_CACHE_PATH="$embedding_cache_path"

requires_models=0
for compose_arg in "$@"; do
  if [[ "$compose_arg" == up || "$compose_arg" == start ]]; then
    requires_models=1
    break
  fi
done

if (( requires_models == 1 )); then
  preset="$(resolve_model_preset)"
  case "$preset" in
    Qwen3.6-35B-A3B)
      model_cache_name="models--unsloth--Qwen3.6-35B-A3B-NVFP4"
      ;;
    Qwen3.6-27B)
      model_cache_name="models--unsloth--Qwen3.6-27B-NVFP4"
      ;;
    *)
      printf 'Unsupported MODEL_PRESET=%q. Choose Qwen3.6-35B-A3B or Qwen3.6-27B.\n' "$preset" >&2
      exit 2
      ;;
  esac

  shopt -s nullglob
  generation_configs=("$cache_path/hub/$model_cache_name"/snapshots/*/config.json)
  embedding_configs=("$embedding_cache_path/models--Qwen--Qwen3-Embedding-0.6B"/snapshots/*/config.json)
  shopt -u nullglob

  generation_ready=0
  for config_path in "${generation_configs[@]}"; do
    [[ -r "$config_path" ]] && generation_ready=1 && break
  done
  embedding_ready=0
  for config_path in "${embedding_configs[@]}"; do
    [[ -r "$config_path" ]] && embedding_ready=1 && break
  done

  if (( generation_ready == 0 || embedding_ready == 0 )); then
    (( generation_ready == 1 )) || printf 'Missing generation checkpoint for %s in %s.\n' "$preset" "$cache_path" >&2
    (( embedding_ready == 1 )) || printf 'Missing Qwen/Qwen3-Embedding-0.6B in %s.\n' "$embedding_cache_path" >&2
    printf 'Provision all required models first with: ./scripts/download-model.sh\n' >&2
    exit 3
  fi
fi

exec docker compose "$@"
