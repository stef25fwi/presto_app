#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

load_local_env_file() {
  local env_file="$1"

  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue

    local key="${line%%=*}"
    local value="${line#*=}"

    key="${key#${key%%[![:space:]]*}}"
    key="${key%${key##*[![:space:]]}}"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'.*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    if [[ -z "${!key:-}" ]]; then
      printf -v "$key" '%s' "$value"
      export "$key"
    fi
  done < "$env_file"
}

read_local_env_value() {
  local env_file="$1"
  local expected_key="$2"

  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue

    local key="${line%%=*}"
    local value="${line#*=}"

    key="${key#${key%%[![:space:]]*}}"
    key="${key%${key##*[![:space:]]}}"
    [[ "$key" != "$expected_key" ]] && continue

    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'.*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    printf '%s' "$value"
    return 0
  done < "$env_file"
}

prefer_local_appcheck_keys() {
  local env_file="$1"
  local local_appcheck=""
  local local_recaptcha=""

  local_appcheck="$(read_local_env_value "$env_file" APPCHECK_RECAPTCHA_SITE_KEY || true)"
  local_recaptcha="$(read_local_env_value "$env_file" RECAPTCHA_ENTERPRISE_SITE_KEY || true)"

  if [[ -n "$local_appcheck" && -n "$local_recaptcha" && "$local_appcheck" == "$local_recaptcha" ]]; then
    if [[ "${APPCHECK_RECAPTCHA_SITE_KEY:-}" != "$local_appcheck" ||
          "${RECAPTCHA_ENTERPRISE_SITE_KEY:-}" != "$local_recaptcha" ]]; then
      echo "[flutter_with_build_stamp] Using aligned App Check keys from .env.local (shell values ignored)." >&2
    fi
    export APPCHECK_RECAPTCHA_SITE_KEY="$local_appcheck"
    export RECAPTCHA_ENTERPRISE_SITE_KEY="$local_recaptcha"
  fi
}

load_local_env_file ".env.local"
prefer_local_appcheck_keys ".env.local"

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

flutter_args=("$@")
if [[ ${#flutter_args[@]} -eq 0 ]]; then
  flutter_args=(build web --release)
fi

# Les tâches VS Code n'héritent pas toujours des exports ajoutés dans ~/.bashrc.
# Si une clé manque, on tente de la relire depuis un shell interactif pour
# éviter de produire un bundle web sans App Check.
hydrate_env_from_interactive_shell() {
  local var_name="$1"
  local current_value="${!var_name:-}"
  local resolved_value=""

  if [[ -n "$current_value" ]]; then
    return 0
  fi

  resolved_value="$(bash -ic "printf '%s' \"\${$var_name:-}\"" 2>/dev/null || true)"
  if [[ -n "$resolved_value" ]]; then
    printf -v "$var_name" '%s' "$resolved_value"
    export "$var_name"
  fi
}

hydrate_env_from_interactive_shell APPCHECK_RECAPTCHA_SITE_KEY
hydrate_env_from_interactive_shell FCM_WEB_VAPID_KEY

if [[ -z "${APPCHECK_RECAPTCHA_SITE_KEY:-}" ]]; then
  if [[ -n "${RECAPTCHA_ENTERPRISE_SITE_KEY:-}" ]]; then
    export APPCHECK_RECAPTCHA_SITE_KEY="$RECAPTCHA_ENTERPRISE_SITE_KEY"
  fi
fi

if [[ -n "${APPCHECK_RECAPTCHA_SITE_KEY:-}" &&
      -n "${RECAPTCHA_ENTERPRISE_SITE_KEY:-}" &&
      "$APPCHECK_RECAPTCHA_SITE_KEY" != "$RECAPTCHA_ENTERPRISE_SITE_KEY" ]]; then
  echo "[flutter_with_build_stamp] ERROR: APPCHECK_RECAPTCHA_SITE_KEY and RECAPTCHA_ENTERPRISE_SITE_KEY differ." >&2
  echo "[flutter_with_build_stamp] Unset the stale shell value or align .env.local before building web." >&2
  exit 3
fi

# Propage les secrets de build s'ils sont définis dans l'environnement.
# Sans ça, un build web local active aucun App Check et Firestore (en mode
# enforce) rejette toutes les lectures publiques avec PERMISSION_DENIED.
# Conventions :
#   - APPCHECK_RECAPTCHA_SITE_KEY      : reCAPTCHA Enterprise pour App Check Web
#   - RECAPTCHA_ENTERPRISE_SITE_KEY    : même site key consommée côté Functions
#   - FCM_WEB_VAPID_KEY                : VAPID key pour notifications web
extra_defines=()
if [[ -n "${APPCHECK_RECAPTCHA_SITE_KEY:-}" ]]; then
  extra_defines+=(--dart-define=APPCHECK_RECAPTCHA_SITE_KEY="$APPCHECK_RECAPTCHA_SITE_KEY")
fi
if [[ -n "${FCM_WEB_VAPID_KEY:-}" ]]; then
  extra_defines+=(--dart-define=FCM_WEB_VAPID_KEY="$FCM_WEB_VAPID_KEY")
fi
# Trace minimale pour diagnostiquer un build sans App Check (Firestore 403).
appcheck_status="absent"
if [[ -n "${APPCHECK_RECAPTCHA_SITE_KEY:-}" ]]; then
  appcheck_status="present(${#APPCHECK_RECAPTCHA_SITE_KEY} chars)"
fi
echo "[flutter_with_build_stamp] APPCHECK_RECAPTCHA_SITE_KEY=$appcheck_status" >&2
echo "[flutter_with_build_stamp] APPCHECK_RECAPTCHA_PROVIDER=enterprise" >&2

is_web_release_build=false
if [[ " ${flutter_args[*]} " == *" build web "* && " ${flutter_args[*]} " == *" --release "* ]]; then
  is_web_release_build=true
fi

if [[ "$is_web_release_build" == "true" && -z "${APPCHECK_RECAPTCHA_SITE_KEY:-}" ]]; then
  echo "[flutter_with_build_stamp] ERROR: APPCHECK_RECAPTCHA_SITE_KEY is required for web release builds." >&2
  echo "[flutter_with_build_stamp] Define it in the environment or .env.local before deploying hosting." >&2
  exit 2
fi

exec flutter "${flutter_args[@]}" \
  --dart-define=APP_VERSION="$app_version" \
  --dart-define=APP_BUILD_NUMBER="$app_build_number" \
  --dart-define=APP_REPOSITORY="$app_repository" \
  --dart-define=APP_BUILD_SHA="$app_build_sha" \
  --dart-define=APP_BUILD_BRANCH="$app_build_branch" \
  --dart-define=APP_BUILD_TAG="$app_build_tag" \
  --dart-define=APP_BUILD_TIME="$app_build_time" \
  "${extra_defines[@]}"
