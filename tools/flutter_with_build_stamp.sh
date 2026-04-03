#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version_line="$(grep -E '^version:' pubspec.yaml | head -n 1 | sed -E 's/^version:[[:space:]]*//')"
app_version="${version_line%%+*}"
app_build_number="0"

if [[ "$version_line" == *"+"* ]]; then
  app_build_number="${version_line##*+}"
fi

app_build_sha="$(git rev-parse --short=12 HEAD 2>/dev/null || echo local)"
app_build_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
app_build_tag="$(git describe --tags --exact-match 2>/dev/null || git describe --tags --abbrev=0 2>/dev/null || echo '')"
origin_url="$(git config --get remote.origin.url 2>/dev/null || echo '')"
app_repository=""

if [[ -n "$origin_url" ]]; then
  app_repository="$(printf '%s\n' "$origin_url" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

app_build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

exec flutter "$@" \
  --dart-define=APP_VERSION="$app_version" \
  --dart-define=APP_BUILD_NUMBER="$app_build_number" \
  --dart-define=APP_REPOSITORY="$app_repository" \
  --dart-define=APP_BUILD_SHA="$app_build_sha" \
  --dart-define=APP_BUILD_BRANCH="$app_build_branch" \
  --dart-define=APP_BUILD_TAG="$app_build_tag" \
  --dart-define=APP_BUILD_TIME="$app_build_time"