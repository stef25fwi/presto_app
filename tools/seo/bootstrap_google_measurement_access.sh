#!/usr/bin/env bash
# Amorçage unique du suivi SEO Google d’iliprestō.
#
# À exécuter dans Google Cloud Shell avec un compte administrateur du projet
# presto-app-74abe. Ce script n'utilise aucune clé de compte de service et ne
# donne pas au compte de déploiement le droit permanent d'activer des API.

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-presto-app-74abe}"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_EMAIL:-github-firebase-deploy@${PROJECT_ID}.iam.gserviceaccount.com}"
REQUIRED_APIS=(
  "searchconsole.googleapis.com"
  "analyticsadmin.googleapis.com"
  "analyticsdata.googleapis.com"
)

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERREUR: gcloud est requis. Utilisez Google Cloud Shell." >&2
  exit 1
fi

ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
if [[ -z "$ACTIVE_ACCOUNT" ]]; then
  echo "ERREUR: aucun compte gcloud actif. Lancez: gcloud auth login" >&2
  exit 1
fi

if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  echo "ERREUR: le compte $ACTIVE_ACCOUNT ne peut pas lire le projet $PROJECT_ID." >&2
  exit 1
fi

if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" \
  --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "ERREUR: compte de service introuvable: $SERVICE_ACCOUNT_EMAIL" >&2
  exit 1
fi

echo "Compte administrateur actif : $ACTIVE_ACCOUNT"
echo "Projet                    : $PROJECT_ID"
echo "Identité du workflow SEO  : $SERVICE_ACCOUNT_EMAIL"
echo
echo "Activation des API de mesure..."
gcloud services enable "${REQUIRED_APIS[@]}" \
  --project "$PROJECT_ID" \
  --quiet

# Autorise uniquement la consommation des API déjà activées. Le rôle qui permet
# de les activer reste réservé au compte administrateur exécutant ce script.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/serviceusage.serviceUsageConsumer" \
  --quiet >/dev/null

echo
echo "Vérification des API :"
for api in "${REQUIRED_APIS[@]}"; do
  enabled="$(
    gcloud services list \
      --enabled \
      --project "$PROJECT_ID" \
      --filter="config.name=${api}" \
      --format='value(config.name)'
  )"
  if [[ "$enabled" != "$api" ]]; then
    echo "ERREUR: l'API $api n'est pas confirmée active." >&2
    exit 1
  fi
  echo "  OK  $api"
done

cat <<EOF

Configuration Google Cloud terminée.

Il reste deux autorisations produit à accorder manuellement à :
  ${SERVICE_ACCOUNT_EMAIL}

1. Search Console
   Propriété : sc-domain:ilipresto.fr
   Paramètres > Utilisateurs et autorisations > Ajouter un utilisateur
   Niveau recommandé : Accès complet

2. Google Analytics 4
   Administration > Propriété > Gestion des accès à la propriété
   Ajouter l'adresse ci-dessus avec le rôle Lecteur.

Après ces deux ajouts, relancez le workflow GitHub Actions :
  SEO continuous monitoring

Le rapport doit afficher 12/12 pages saines, Search Console « available »
et GA4 « available ». L'issue #1173 se fermera alors automatiquement.
EOF
