#!/usr/bin/env bash
set -euo pipefail

# Met en conformité la configuration Firebase Phone Auth d'iliprestō.
#
# Le script est idempotent et ne modifie que :
# - l'activation du provider Phone ;
# - la politique des régions SMS nécessaires à l'application ;
# - les empreintes SHA manquantes de l'app Android fr.ilipresto.app.
#
# Authentification attendue : `gcloud auth print-access-token` (WIF en CI).

PROJECT_ID="${FIREBASE_PROJECT_ID:-presto-app-74abe}"
CURRENT_ANDROID_APP_ID="${FIREBASE_ANDROID_APP_ID:-1:151421230024:android:339090c7418b3d7c2b3efd}"
LEGACY_ANDROID_APP_ID="${FIREBASE_LEGACY_ANDROID_APP_ID:-1:151421230024:android:c07e48f2a8df85842b3efd}"
MODE="${1:---check}"

# Régions correspondant aux indicatifs actuellement acceptés dans l'app :
# +33, +590, +596, +594, +262 et +689.
REQUIRED_SMS_REGIONS=(FR GP BL MF MQ GF RE YT PF)

case "$MODE" in
  --check|--apply) ;;
  *)
    echo "Usage: $0 [--check|--apply]" >&2
    exit 2
    ;;
esac

for command in gcloud curl jq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "::error::$command est requis pour contrôler Firebase Phone Auth." >&2
    exit 2
  fi
done

TOKEN="$(gcloud auth print-access-token --project="$PROJECT_ID")"
if [[ -z "$TOKEN" ]]; then
  echo "::error::Impossible d'obtenir un jeton Google Cloud." >&2
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"
IDENTITY_CONFIG_URL="https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config"

http_json() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local output_file
  output_file="$(mktemp)"
  local status

  if [[ -n "$body" ]]; then
    status="$(curl --silent --show-error \
      --request "$method" \
      --header "$AUTH_HEADER" \
      --header 'Content-Type: application/json' \
      --data "$body" \
      --output "$output_file" \
      --write-out '%{http_code}' \
      "$url")"
  else
    status="$(curl --silent --show-error \
      --request "$method" \
      --header "$AUTH_HEADER" \
      --output "$output_file" \
      --write-out '%{http_code}' \
      "$url")"
  fi

  if [[ ! "$status" =~ ^[0-9]{3}$ || "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "::error::API Google $method $url → HTTP ${status:-inconnu}" >&2
    jq -c '{error: .error // .}' "$output_file" 2>/dev/null >&2 || cat "$output_file" >&2
    rm -f "$output_file"
    return 1
  fi

  cat "$output_file"
  rm -f "$output_file"
}

normalize_sha_value() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]:'
}

contains_normalized_sha() {
  local certs_json="$1"
  local candidate
  candidate="$(normalize_sha_value "$2")"

  jq -e --arg candidate "$candidate" '
    any(.certificates[]?;
      (((.shaHash // "") | ascii_upcase | gsub(":"; "")) == $candidate)
    )
  ' <<<"$certs_json" >/dev/null
}

list_sha_certificates() {
  local app_id="$1"
  http_json GET "https://firebase.googleapis.com/v1beta1/projects/-/androidApps/${app_id}/sha"
}

register_sha_if_missing() {
  local certs_json="$1"
  local raw_sha_hash="$2"
  local cert_type="$3"

  [[ -z "$raw_sha_hash" ]] && return 0

  local sha_hash
  sha_hash="$(normalize_sha_value "$raw_sha_hash")"

  if contains_normalized_sha "$certs_json" "$sha_hash"; then
    echo "✅ ${cert_type} déjà enregistrée pour fr.ilipresto.app."
    return 0
  fi

  if [[ "$MODE" != "--apply" ]]; then
    echo "❌ ${cert_type} manquante pour fr.ilipresto.app : ${sha_hash}"
    PHONE_CONFIG_DRIFT=1
    return 0
  fi

  local payload
  payload="$(jq -cn --arg hash "$sha_hash" --arg type "$cert_type" \
    '{shaHash: $hash, certType: $type}')"
  http_json POST \
    "https://firebase.googleapis.com/v1beta1/projects/-/androidApps/${CURRENT_ANDROID_APP_ID}/sha" \
    "$payload" >/dev/null
  echo "✅ ${cert_type} ajoutée à fr.ilipresto.app."
}

PHONE_CONFIG_DRIFT=0

echo "═══ Firebase Phone Auth — projet ${PROJECT_ID} ═══"
config_json="$(http_json GET "$IDENTITY_CONFIG_URL")"

phone_enabled="$(jq -r '.signIn.phoneNumber.enabled // false' <<<"$config_json")"
if [[ "$phone_enabled" == "true" ]]; then
  echo "✅ Provider Téléphone activé."
else
  echo "❌ Provider Téléphone désactivé."
  PHONE_CONFIG_DRIFT=1
fi

required_regions_json="$(printf '%s\n' "${REQUIRED_SMS_REGIONS[@]}" | jq -R . | jq -s 'unique')"
policy_kind="none"
next_sms_policy='{}'

if jq -e '.smsRegionConfig.allowlistOnly != null' <<<"$config_json" >/dev/null; then
  policy_kind="allowlistOnly"
  existing_regions="$(jq -c '.smsRegionConfig.allowlistOnly.allowedRegions // []' <<<"$config_json")"
  merged_regions="$(jq -cn \
    --argjson existing "$existing_regions" \
    --argjson required "$required_regions_json" \
    '$existing + $required | unique')"
  next_sms_policy="$(jq -cn --argjson regions "$merged_regions" \
    '{allowlistOnly: {allowedRegions: $regions}}')"

  missing_regions="$(jq -cn \
    --argjson existing "$existing_regions" \
    --argjson required "$required_regions_json" \
    '$required - $existing')"
  if [[ "$(jq 'length' <<<"$missing_regions")" -gt 0 ]]; then
    echo "❌ Régions SMS absentes de l'allowlist : $(jq -r 'join(", ")' <<<"$missing_regions")"
    PHONE_CONFIG_DRIFT=1
  else
    echo "✅ Régions SMS requises autorisées (allowlist)."
  fi
elif jq -e '.smsRegionConfig.allowByDefault != null' <<<"$config_json" >/dev/null; then
  policy_kind="allowByDefault"
  disallowed_regions="$(jq -c '.smsRegionConfig.allowByDefault.disallowedRegions // []' <<<"$config_json")"
  next_disallowed="$(jq -cn \
    --argjson blocked "$disallowed_regions" \
    --argjson required "$required_regions_json" \
    '$blocked - $required | unique')"
  next_sms_policy="$(jq -cn --argjson regions "$next_disallowed" \
    '{allowByDefault: {disallowedRegions: $regions}}')"

  blocked_required="$(jq -cn \
    --argjson blocked "$disallowed_regions" \
    --argjson required "$required_regions_json" \
    '$required - ($required - $blocked)')"
  if [[ "$(jq 'length' <<<"$blocked_required")" -gt 0 ]]; then
    echo "❌ Régions SMS requises explicitement bloquées : $(jq -r 'join(", ")' <<<"$blocked_required")"
    PHONE_CONFIG_DRIFT=1
  else
    echo "✅ Régions SMS requises autorisées (allow by default)."
  fi
else
  policy_kind="allowlistOnly"
  next_sms_policy="$(jq -cn --argjson regions "$required_regions_json" \
    '{allowlistOnly: {allowedRegions: $regions}}')"
  echo "❌ Aucune politique SMS exploitable : création d'une allowlist minimale requise."
  PHONE_CONFIG_DRIFT=1
fi

if [[ "$MODE" == "--apply" && "$PHONE_CONFIG_DRIFT" -ne 0 ]]; then
  patch_payload="$(jq -cn \
    --argjson sms "$next_sms_policy" \
    '{signIn: {phoneNumber: {enabled: true}}, smsRegionConfig: $sms}')"
  http_json PATCH \
    "${IDENTITY_CONFIG_URL}?updateMask=sign_in.phone_number.enabled,sms_region_config" \
    "$patch_payload" >/dev/null
  echo "✅ Provider Téléphone et politique régions SMS appliqués (${policy_kind})."

  # Certifier immédiatement l'état persistant plutôt que de faire confiance au
  # seul code HTTP de la requête PATCH.
  config_json="$(http_json GET "$IDENTITY_CONFIG_URL")"
  if [[ "$(jq -r '.signIn.phoneNumber.enabled // false' <<<"$config_json")" != "true" ]]; then
    echo "::error::Le provider Téléphone reste désactivé après PATCH." >&2
    PHONE_CONFIG_DRIFT=1
  else
    PHONE_CONFIG_DRIFT=0
  fi

  for region in "${REQUIRED_SMS_REGIONS[@]}"; do
    if jq -e --arg region "$region" '
      if .smsRegionConfig.allowlistOnly != null then
        (.smsRegionConfig.allowlistOnly.allowedRegions // []) | index($region) != null
      elif .smsRegionConfig.allowByDefault != null then
        ((.smsRegionConfig.allowByDefault.disallowedRegions // []) | index($region)) == null
      else
        false
      end
    ' <<<"$config_json" >/dev/null; then
      :
    else
      echo "::error::La région SMS ${region} reste bloquée après PATCH." >&2
      PHONE_CONFIG_DRIFT=1
    fi
  done
fi

echo "═══ Empreintes Android Firebase ═══"
current_certs="$(list_sha_certificates "$CURRENT_ANDROID_APP_ID")"
legacy_certs="$(list_sha_certificates "$LEGACY_ANDROID_APP_ID")"

# Les certificats historiques représentent les clés déjà utilisées par le même
# produit avant le passage de com.presto.app à fr.ilipresto.app. Copier les
# empreintes manquantes évite de perdre la clé Play/App Signing déjà connue.
while IFS=$'\t' read -r hash cert_type; do
  [[ -z "$hash" || -z "$cert_type" ]] && continue
  register_sha_if_missing "$current_certs" "$hash" "$cert_type"
done < <(jq -r '.certificates[]? | [.shaHash, .certType] | @tsv' <<<"$legacy_certs")

# Relire avant d'ajouter la clé release : elle peut être identique à une
# empreinte que l'on vient de migrer depuis l'ancienne app Firebase.
if [[ "$MODE" == "--apply" ]]; then
  current_certs="$(list_sha_certificates "$CURRENT_ANDROID_APP_ID")"
fi

# Empreintes de la clé release réellement utilisée par la CI actuelle.
register_sha_if_missing "$current_certs" "${ANDROID_RELEASE_SHA1:-}" SHA_1
if [[ "$MODE" == "--apply" ]]; then
  current_certs="$(list_sha_certificates "$CURRENT_ANDROID_APP_ID")"
fi
register_sha_if_missing "$current_certs" "${ANDROID_RELEASE_SHA256:-}" SHA_256

if [[ "$MODE" == "--apply" ]]; then
  # Relire après les créations pour certifier l'état réellement persistant.
  current_certs="$(list_sha_certificates "$CURRENT_ANDROID_APP_ID")"
fi

sha1_count="$(jq '[.certificates[]? | select(.certType == "SHA_1")] | length' <<<"$current_certs")"
sha256_count="$(jq '[.certificates[]? | select(.certType == "SHA_256")] | length' <<<"$current_certs")"
echo "Empreintes fr.ilipresto.app : SHA-1=${sha1_count}, SHA-256=${sha256_count}"

if [[ "$sha1_count" -lt 1 ]]; then
  echo "::error::Aucune SHA-1 n'est enregistrée pour fr.ilipresto.app (fallback reCAPTCHA impossible)." >&2
  PHONE_CONFIG_DRIFT=1
fi
if [[ "$sha256_count" -lt 1 ]]; then
  echo "::error::Aucune SHA-256 n'est enregistrée pour fr.ilipresto.app (Play Integrity Phone Auth incomplet)." >&2
  PHONE_CONFIG_DRIFT=1
fi

# Contrôle non bloquant de la facturation : l'API de facturation peut ne pas
# être lisible par le compte de service de déploiement. Si elle répond, Blaze
# est impératif pour envoyer de vrais SMS Firebase Auth.
billing_file="$(mktemp)"
billing_status="$(curl --silent --show-error \
  --header "$AUTH_HEADER" \
  --output "$billing_file" \
  --write-out '%{http_code}' \
  "https://cloudbilling.googleapis.com/v1/projects/${PROJECT_ID}/billingInfo" || true)"
if [[ "$billing_status" == "200" ]]; then
  if jq -e '.billingEnabled == true' "$billing_file" >/dev/null; then
    echo "✅ Facturation Google Cloud active (compatible SMS pay-as-you-go)."
  else
    echo "::error::Facturation désactivée : Firebase Auth ne peut pas envoyer de vrais SMS sur le plan Spark." >&2
    PHONE_CONFIG_DRIFT=1
  fi
else
  echo "ℹ️ Facturation non vérifiable avec le rôle CI (HTTP ${billing_status:-inconnu})."
fi
rm -f "$billing_file"

if [[ "$PHONE_CONFIG_DRIFT" -ne 0 ]]; then
  if [[ "$MODE" == "--check" ]]; then
    echo "::error::Configuration Firebase Phone Auth non conforme. Lance le workflow SMS Auth Config en mode apply." >&2
  else
    echo "::error::Configuration Firebase Phone Auth encore incomplète après réparation." >&2
  fi
  exit 1
fi

echo "✅ Configuration Firebase Phone Auth certifiée pour iliprestō."
