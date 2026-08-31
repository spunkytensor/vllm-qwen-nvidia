#!/usr/bin/env bash

set -euo pipefail

readonly PRESET_27B="Qwen3.8-27B"

MODEL_PRESET="${MODEL_PRESET:-$PRESET_27B}"

if [[ -z "${VLLM_API_KEY:-}" ]]; then
  printf 'VLLM_API_KEY must be set and non-empty.\n' >&2
  exit 2
fi

case "$MODEL_PRESET" in
  "$PRESET_27B")
    model_id="unsloth/Qwen3.8-27B-NVFP4"
    preset_max_model_len="130000"
    preset_gpu_memory_utilization="0.93"
    preset_mtp_tokens="2"
    ;;
  *)
    printf 'Unsupported MODEL_PRESET=%q. Choose %s.\n' \
      "$MODEL_PRESET" "$PRESET_27B" >&2
    exit 2
    ;;
esac

max_model_len="${MAX_MODEL_LEN:-$preset_max_model_len}"
gpu_memory_utilization="${GPU_MEMORY_UTILIZATION:-$preset_gpu_memory_utilization}"
max_num_seqs="${MAX_NUM_SEQS:-1}"
max_num_batched_tokens="${MAX_NUM_BATCHED_TOKENS:-8192}"

require_positive_integer() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s must be a positive integer; got %q.\n' "$name" "$value" >&2
    exit 2
  fi
}

require_positive_integer MAX_MODEL_LEN "$max_model_len"
require_positive_integer MAX_NUM_SEQS "$max_num_seqs"
require_positive_integer MAX_NUM_BATCHED_TOKENS "$max_num_batched_tokens"

if ! [[ "$gpu_memory_utilization" =~ ^(0\.[0-9]+|1(\.0+)?)$ ]] \
  || [[ "$gpu_memory_utilization" =~ ^0\.0+$ ]]; then
  printf 'GPU_MEMORY_UTILIZATION must be greater than 0 and at most 1; got %q.\n' \
    "$gpu_memory_utilization" >&2
  exit 2
fi

# The root filesystem is read-only; these live on the tmpfs and so must be
# recreated on every start. Libraries that expect them to pre-exist would
# otherwise fail before vLLM prints anything useful.
mkdir -p "${HF_MODULES_CACHE:-/tmp/hf-modules}" "${XDG_CONFIG_HOME:-/tmp/config}"

model_cache_dir="$HF_HOME/hub/models--${model_id//\//--}"
shopt -s nullglob
cached_configs=("$model_cache_dir"/snapshots/*/config.json)
shopt -u nullglob
model_is_cached=0
for config_path in "${cached_configs[@]}"; do
  if [[ -r "$config_path" ]]; then
    model_is_cached=1
    break
  fi
done
if (( model_is_cached == 0 )); then
  printf 'Model %s is not present in the read-only host Hugging Face cache at %s.\n' \
    "$model_id" "$HF_HOME" >&2
  printf 'Download it on the host first with: ./scripts/download-model.sh\n' >&2
  exit 3
fi

printf 'Launching preset=%s model=%s context=%s gpu_memory_utilization=%s max_num_seqs=%s mtp_tokens=%s\n' \
  "$MODEL_PRESET" "$model_id" "$max_model_len" "$gpu_memory_utilization" \
  "$max_num_seqs" "$preset_mtp_tokens"

args=(
  serve "$model_id"
  --served-model-name "$MODEL_PRESET"
  --host 0.0.0.0
  --port 8000
  --dtype auto
  --max-model-len "$max_model_len"
  --gpu-memory-utilization "$gpu_memory_utilization"
  --kv-cache-dtype fp8
  --max-num-seqs "$max_num_seqs"
  --max-num-batched-tokens "$max_num_batched_tokens"
  --no-enable-prefix-caching
  --enable-chunked-prefill
  --reasoning-parser qwen3
  --enable-auto-tool-choice
  --tool-call-parser qwen3_coder
  --limit-mm-per-prompt '{"image":1,"video":0}'
)

if (( preset_mtp_tokens > 0 )); then
  args+=(--speculative-config \
    "{\"method\":\"mtp\",\"num_speculative_tokens\":${preset_mtp_tokens}}")
fi

exec vllm "${args[@]}"
