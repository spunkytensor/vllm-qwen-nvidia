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

tokenizer_fix_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/vllm-qwen-nvidia"
if [[ "$tokenizer_fix_dir" != /* ]]; then
  printf 'The tokenizer overlay cache path must be absolute; got %q.\n' "$tokenizer_fix_dir" >&2
  exit 2
fi

# Earlier Unsloth revisions compiled a 2,048-token truncation limit into
# tokenizer.json. Compose overlays an idempotently corrected copy without
# modifying the Hugging Face snapshot. Placeholder values keep commands that do
# not create containers renderable before the checkpoint has been downloaded.
VLLM_TOKENIZER_FIX_PATH="$tokenizer_fix_dir/tokenizer-not-downloaded.json"
VLLM_TOKENIZER_TARGET="/home/vllm/.cache/huggingface/tokenizer-not-downloaded.json"
export VLLM_TOKENIZER_FIX_PATH VLLM_TOKENIZER_TARGET

compose_args=("$@")
compose_subcommand=""
arg_index=0
while (( arg_index < ${#compose_args[@]} )); do
  compose_arg="${compose_args[$arg_index]}"
  case "$compose_arg" in
    --all-resources|--compatibility|--dry-run)
      ((arg_index += 1))
      ;;
    --ansi|--env-file|-f|--file|--parallel|--profile|--progress|--project-directory|-p|--project-name)
      ((arg_index += 2))
      ;;
    --ansi=*|--env-file=*|--file=*|--parallel=*|--profile=*|--progress=*|--project-directory=*|--project-name=*)
      ((arg_index += 1))
      ;;
    --)
      ((arg_index += 1))
      if (( arg_index < ${#compose_args[@]} )); then
        compose_subcommand="${compose_args[$arg_index]}"
      fi
      break
      ;;
    -*)
      # Let Docker Compose report unsupported global options.
      ((arg_index += 1))
      ;;
    *)
      compose_subcommand="$compose_arg"
      break
      ;;
  esac
done

requires_models=0
case "$compose_subcommand" in
  up|create|run)
    requires_models=1
    ;;
esac

if (( requires_models == 1 )); then
  preset="$(resolve_model_preset)"
  case "$preset" in
    Qwen3.8-27B)
      model_cache_name="models--unsloth--Qwen3.8-27B-NVFP4"
      ;;
    *)
      printf 'Unsupported MODEL_PRESET=%q. Choose Qwen3.8-27B.\n' "$preset" >&2
      exit 2
      ;;
  esac

  model_cache_dir="$cache_path/hub/$model_cache_name"
  shopt -s nullglob
  generation_configs=()
  if [[ -r "$model_cache_dir/refs/main" ]]; then
    model_revision="$(<"$model_cache_dir/refs/main")"
    generation_configs+=("$model_cache_dir/snapshots/$model_revision/config.json")
  else
    generation_configs=("$model_cache_dir"/snapshots/*/config.json)
  fi
  embedding_configs=("$embedding_cache_path/models--Qwen--Qwen3-Embedding-0.6B"/snapshots/*/config.json)
  shopt -u nullglob

  generation_ready=0
  generation_snapshot=""
  for config_path in "${generation_configs[@]}"; do
    if [[ -r "$config_path" ]]; then
      generation_ready=1
      generation_snapshot="${config_path%/config.json}"
      break
    fi
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

  tokenizer_path="$generation_snapshot/tokenizer.json"
  if [[ ! -r "$tokenizer_path" ]]; then
    printf 'Missing tokenizer.json for %s in %s.\n' "$preset" "$generation_snapshot" >&2
    exit 3
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required to prepare the Qwen3.8 tokenizer safeguard.\n' >&2
    exit 2
  fi

  tokenizer_fix_path="$tokenizer_fix_dir/${generation_snapshot##*/}-tokenizer.json"
  tokenizer_fix_tmp="$tokenizer_fix_path.tmp.$$"
  mkdir -p "$tokenizer_fix_dir"
  if ! jq '.truncation = null' "$tokenizer_path" > "$tokenizer_fix_tmp"; then
    rm -f "$tokenizer_fix_tmp"
    printf 'Could not prepare corrected tokenizer from %s.\n' "$tokenizer_path" >&2
    exit 3
  fi
  chmod 0444 "$tokenizer_fix_tmp"
  mv -f "$tokenizer_fix_tmp" "$tokenizer_fix_path"

  snapshot_relative_path="${generation_snapshot#"$cache_path"/}"
  VLLM_TOKENIZER_FIX_PATH="$tokenizer_fix_path"
  VLLM_TOKENIZER_TARGET="/home/vllm/.cache/huggingface/$snapshot_relative_path/tokenizer.json"
  export VLLM_TOKENIZER_FIX_PATH VLLM_TOKENIZER_TARGET
fi

exec docker compose "$@"
