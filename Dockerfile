ARG VLLM_BASE_IMAGE=vllm/vllm-openai:v0.25.1
FROM ${VLLM_BASE_IMAGE}

# HF_TOKEN is deliberately absent: baking a token into an image layer would expose it
# via `docker inspect`. It is only needed for gated/private repos (this checkpoint is
# public); put it in .env, which docker-compose.yml passes through at run time.

# The root filesystem is read-only at run time. Only /home/vllm/.cache/vllm (the
# vllm-runtime-cache volume) and /tmp are writable, so every path that a library
# may write to must live under one of those two. /home/vllm/.cache/huggingface is
# the read-only host checkpoint mount and must never be a write target.
ENV HOME=/home/vllm \
    USER=vllm \
    LOGNAME=vllm \
    HF_HOME=/home/vllm/.cache/huggingface \
    HF_MODULES_CACHE=/tmp/hf-modules \
    XDG_CACHE_HOME=/home/vllm/.cache/vllm \
    XDG_CONFIG_HOME=/tmp/config \
    VLLM_CACHE_ROOT=/home/vllm/.cache/vllm \
    TORCH_HOME=/home/vllm/.cache/vllm/torch \
    TORCHINDUCTOR_CACHE_DIR=/home/vllm/.cache/vllm/torchinductor \
    FLASHINFER_WORKSPACE_BASE=/home/vllm/.cache/vllm \
    TRITON_CACHE_DIR=/home/vllm/.cache/vllm/triton \
    CUDA_CACHE_PATH=/home/vllm/.cache/vllm/cuda

# Read by vLLM directly rather than via a flag.
# The configured context is within the checkpoint's native limit, so the long-length
# override stays off — it would only mask a genuine misconfiguration.
ENV VLLM_ALLOW_LONG_MAX_MODEL_LEN=0 \
    VLLM_USE_FLASHINFER_SAMPLER=0 \
    OMP_NUM_THREADS=4

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Versions required by Unsloth's Qwen3.8 NVFP4 guide. Keep vLLM supplied by the base
# image, but ensure its native NVFP4/CUTLASS runtime dependencies are recent enough.
RUN uv pip install --system \
    "flashinfer-python==0.6.13" \
    "nvidia-cutlass-dsl==4.5.2"

COPY --chmod=755 scripts/serve.sh /opt/vllm/serve.sh

# vLLM v0.25.1 provides this fixed non-root account. Prepare every mutable
# runtime path before dropping privileges; package installation above remains a
# build-time root operation only.
RUN mkdir -p \
      /home/vllm/.cache/huggingface \
      /home/vllm/.cache/vllm/cuda \
      /home/vllm/.cache/vllm/torch \
      /home/vllm/.cache/vllm/triton \
      /home/vllm/.cache/vllm/torchinductor \
    && chown -R 2000:0 /home/vllm \
    && chmod -R g+rwX /home/vllm

USER 2000:0

ENTRYPOINT ["/opt/vllm/serve.sh"]
