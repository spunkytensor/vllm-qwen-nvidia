#!/usr/bin/env bash
# Match the shared policy for locally built images the reusable job cannot accept.
set -euo pipefail
report=${1:?Usage: security-gate.sh trivy.json}
jq -e '.SchemaVersion == 2 and (.Results | type == "array") and
  ([.Results[]?.Packages[]?] | length > 0)' "$report" >/dev/null
count=$(jq '[.Results[]?.Vulnerabilities[]? |
  select(.Severity == "HIGH" or .Severity == "CRITICAL")] | length' "$report")
echo "High/Critical findings: $count"
test "$count" -eq 0
