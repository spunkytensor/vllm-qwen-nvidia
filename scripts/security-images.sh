#!/usr/bin/env bash
# Resolve current upstream defaults, not project releases or user build overrides.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
images='[]'
for file in Dockerfile Dockerfile.open-terminal Dockerfile.open-webui; do
  ref=$(sed -nE 's/^ARG [A-Z_]+_BASE_IMAGE=(.*)$/\1/p' "$file")
  test -n "$ref"
  manifest=$(docker manifest inspect --verbose "$ref")
  digest=$(jq -er '[if type == "array" then .[] else . end | .Descriptor |
    select(.platform.os == "linux" and .platform.architecture == "amd64")] |
    if length == 1 then .[0].digest else error("Expected one Linux amd64 manifest") end' <<< "$manifest")
  [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
  name=${file#Dockerfile}
  name=${name#.}
  name=${name:-vllm}
  images=$(jq -c --arg name "$name" --arg tag "$ref" --arg image "${ref%:*}@$digest" \
    '. + [{name: $name, tag: $tag, image: $image}]' <<< "$images")
done
jq -c '{include: .}' <<< "$images"
