ARG VLLM_BASE_IMAGE=vllm/vllm-openai:v0.25.1
FROM ${VLLM_BASE_IMAGE}

# HF_TOKEN is deliberately absent: baking a token into an image layer would expose it
# via `docker inspect`. It is only needed for gated/private repos (this checkpoint is
# public); put it in .env, which docker-compose.yml passes through at run time.

ENV HF_HOME=/root/.cache/huggingface

# Read by vLLM directly rather than via a flag.
# The configured context is within the checkpoint's native limit, so the long-length
# override stays off — it would only mask a genuine misconfiguration.
ENV VLLM_ALLOW_LONG_MAX_MODEL_LEN=0 \
    VLLM_USE_FLASHINFER_SAMPLER=0 \
    OMP_NUM_THREADS=4

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Versions required by Unsloth's Qwen3.6 NVFP4 guide. Keep vLLM supplied by the base
# image, but ensure its native NVFP4/CUTLASS runtime dependencies are recent enough.
RUN uv pip install --system \
    "flashinfer-python==0.6.13" \
    "nvidia-cutlass-dsl==4.5.2"

COPY --chmod=755 scripts/serve.sh /opt/vllm/serve.sh

ENTRYPOINT ["/opt/vllm/serve.sh"]
