#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-https://ilipresto.web.app}"
OUT_DIR="${OUT_DIR:-quality_reports/production-smoke}"
mkdir -p "$OUT_DIR"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
report="$OUT_DIR/smoke-${started_at//:/-}.txt"

check_url() {
  local path="$1"
  local expected_type="${2:-}"
  local body
  body="$(mktemp)"
  trap 'rm -f "$body"' RETURN

  local code
  code="$(curl --fail-with-body --location --silent --show-error \
    --retry 4 --retry-delay 3 --retry-all-errors --max-time 45 \
    --output "$body" --write-out '%{http_code}' "$BASE_URL$path")"

  local bytes
  bytes="$(wc -c <"$body" | tr -d ' ')"
  printf '%s HTTP=%s BYTES=%s\n' "$path" "$code" "$bytes" | tee -a "$report"

  test "$code" = "200"
  test "$bytes" -gt 0

  if [[ -n "$expected_type" ]]; then
    local content_type
    content_type="$(curl --head --location --silent --show-error --max-time 30 "$BASE_URL$path" \
      | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type" {print tolower($2); exit}')"
    printf '%s CONTENT_TYPE=%s\n' "$path" "$content_type" | tee -a "$report"
    [[ "$content_type" == *"$expected_type"* ]]
  fi
}

{
  echo "started_at=$started_at"
  echo "base_url=$BASE_URL"
  echo "git_sha=${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
} > "$report"

check_url "/" "text/html"
check_url "/manifest.json" "application/json"
check_url "/flutter_bootstrap.js" "javascript"

if grep -qi '<!doctype html\|<html' <(curl --location --silent --show-error "$BASE_URL/flutter_bootstrap.js"); then
  echo "ERROR: flutter_bootstrap.js returned HTML" | tee -a "$report"
  exit 1
fi

echo "status=success" | tee -a "$report"
echo "Smoke tests passed: $report"
