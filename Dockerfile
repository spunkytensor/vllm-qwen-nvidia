FROM vllm/vllm-openai:v0.25.1@sha256:e4f88a835143cd22aee2397a26ec6bb80b3a4a6fe0c882bcbc63822904766089

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

# Apply Ubuntu security updates published after the upstream image was built.
# Only /etc/apt/sources.list (the Ubuntu archive) is used, so the CUDA and Python
# PPA packages that vLLM was built against stay at the base image's versions.
RUN apt-get -o Dir::Etc::SourceParts=- update \
    && DEBIAN_FRONTEND=noninteractive apt-get -o Dir::Etc::SourceParts=- upgrade -y --no-install-recommends \
    && apt-get -o Dir::Etc::SourceParts=- install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# The base image already fails `uv pip check` (nixl pins an older nixl-cu13), so
# fail only on dependency conflicts that these installs introduce.
COPY docker/vllm/requirements.txt /tmp/vllm-requirements.txt
RUN (uv pip check --system 2>&1 || true) | grep -F ' requires ' > /tmp/pip-check-base.txt; \
    uv pip install --system -r /tmp/vllm-requirements.txt \
    && (uv pip check --system 2>&1 || true) | grep -F ' requires ' | diff /tmp/pip-check-base.txt - \
    && rm /tmp/vllm-requirements.txt /tmp/pip-check-base.txt

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
