#!/usr/bin/env bash
# Crée une alerte Cloud Monitoring qui se déclenche si App Check est
# désactivé en production (log CRITICAL_APP_CHECK_DISABLED émis par
# functions/index.js::assertProdSecurityConfig).
#
# Usage :
#   ./scripts/setup_appcheck_alert.sh [email@notification]
#
# Prérequis : gcloud authentifié sur le projet presto-app-74abe.

set -euo pipefail

PROJECT_ID="presto-app-74abe"
METRIC_NAME="appcheck_disabled_in_prod"
NOTIFICATION_EMAIL="${1:-}"

echo "── 1/3 Métrique log-based '${METRIC_NAME}'"
if gcloud logging metrics describe "${METRIC_NAME}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo "   Déjà présente — ok."
else
  gcloud logging metrics create "${METRIC_NAME}" \
    --project="${PROJECT_ID}" \
    --description="App Check desactive en production (CRITICAL_APP_CHECK_DISABLED)" \
    --log-filter='resource.type="cloud_function" OR resource.type="cloud_run_revision"
textPayload:"CRITICAL_APP_CHECK_DISABLED" OR jsonPayload.message:"CRITICAL_APP_CHECK_DISABLED"'
  echo "   Créée."
fi

CHANNEL_ARGS=()
if [[ -n "${NOTIFICATION_EMAIL}" ]]; then
  echo "── 2/3 Canal de notification email ${NOTIFICATION_EMAIL}"
  CHANNEL=$(gcloud beta monitoring channels list \
    --project="${PROJECT_ID}" \
    --filter="type=email AND labels.email_address=${NOTIFICATION_EMAIL}" \
    --format="value(name)" | head -1)
  if [[ -z "${CHANNEL}" ]]; then
    CHANNEL=$(gcloud beta monitoring channels create \
      --project="${PROJECT_ID}" \
      --display-name="Alerte securite Presto" \
      --type=email \
      --channel-labels="email_address=${NOTIFICATION_EMAIL}" \
      --format="value(name)")
    echo "   Créé : ${CHANNEL}"
  else
    echo "   Déjà présent : ${CHANNEL}"
  fi
  CHANNEL_ARGS=(--notification-channels="${CHANNEL}")
else
  echo "── 2/3 Pas d'email fourni — alerte sans canal (visible console uniquement)."
fi

echo "── 3/3 Politique d'alerte"
POLICY_NAME="App Check désactivé en production"
EXISTING=$(gcloud alpha monitoring policies list \
  --project="${PROJECT_ID}" \
  --filter="displayName='${POLICY_NAME}'" \
  --format="value(name)" | head -1)
if [[ -n "${EXISTING}" ]]; then
  echo "   Déjà présente — ok."
else
  gcloud alpha monitoring policies create \
    --project="${PROJECT_ID}" \
    --display-name="${POLICY_NAME}" \
    --condition-display-name="CRITICAL_APP_CHECK_DISABLED détecté" \
    --condition-filter="metric.type=\"logging.googleapis.com/user/${METRIC_NAME}\" resource.type=\"cloud_function\"" \
    --condition-threshold-value=0 \
    --condition-threshold-comparison=COMPARISON_GT \
    --condition-threshold-duration=0s \
    --combiner=OR \
    "${CHANNEL_ARGS[@]}"
  echo "   Créée."
fi

echo "✅ Terminé. Toute désactivation d'App Check en prod déclenchera l'alerte."
