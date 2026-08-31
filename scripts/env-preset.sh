# Shared by compose.sh and download-model.sh. Source, do not execute.
#
# Resolves MODEL_PRESET from the environment, falling back to a bare read of
# .env. This is not a shell parser: it accepts the forms `docker compose`
# itself accepts for a simple value -- an optional `export ` prefix, optional
# single or double quotes, an inline `#` comment on unquoted values, and
# surrounding whitespace. The last assignment wins, matching .env semantics.

readonly DEFAULT_MODEL_PRESET="Qwen3.8-27B"

resolve_model_preset() {
  local preset="${MODEL_PRESET:-}"

  if [[ -z "$preset" && -f .env ]]; then
    preset="$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}MODEL_PRESET[[:space:]]*=[[:space:]]*//p' .env | tail -n 1)"
    preset="${preset%$'\r'}"
    # Trim leading whitespace before inspecting the first character.
    preset="${preset#"${preset%%[![:space:]]*}"}"

    if [[ "$preset" == '"'* ]]; then
      preset="${preset#\"}"
      preset="${preset%%\"*}"
    elif [[ "$preset" == "'"* ]]; then
      preset="${preset#\'}"
      preset="${preset%%\'*}"
    else
      preset="${preset%%#*}"
      preset="${preset%"${preset##*[![:space:]]}"}"
    fi
  fi

  printf '%s' "${preset:-$DEFAULT_MODEL_PRESET}"
}
