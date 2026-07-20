#!/usr/bin/env bash
# Provisionne Workload Identity Federation (WIF) pour que les workflows GitHub
# Actions s'authentifient sur GCP SANS clé de service account longue durée.
#
# À lancer UNE FOIS avec gcloud authentifié en tant qu'admin du projet
# (roles/iam.workloadIdentityPoolAdmin + roles/iam.serviceAccountAdmin).
#
# Après exécution, ce script imprime les deux valeurs à ajouter comme secrets
# dans l'environnement GitHub `recaptcha` :
#   - WIF_PROVIDER
#   - WIF_SERVICE_ACCOUNT
#
# Référence : https://github.com/google-github-actions/auth#workload-identity-federation

set -euo pipefail

# --- Paramètres (adapter si besoin) ------------------------------------------
PROJECT_ID="presto-app-74abe"
SERVICE_ACCOUNT_EMAIL="github-firebase-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
GITHUB_REPO="stef25fwi/presto_app"          # owner/repo autorisé
POOL_ID="github-actions"
POOL_DISPLAY="GitHub Actions"
PROVIDER_ID="github"
PROVIDER_DISPLAY="GitHub OIDC"
# -----------------------------------------------------------------------------

echo "== Projet : $PROJECT_ID =="
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
echo "Numéro de projet : $PROJECT_NUMBER"

echo "== 1/4 Activation des API nécessaires =="
gcloud services enable iamcredentials.googleapis.com sts.googleapis.com \
  --project "$PROJECT_ID"

echo "== 2/4 Pool d'identité (idempotent) =="
if ! gcloud iam workload-identity-pools describe "$POOL_ID" \
      --project "$PROJECT_ID" --location=global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project "$PROJECT_ID" --location=global \
    --display-name="$POOL_DISPLAY"
else
  echo "Pool $POOL_ID déjà présent."
fi

echo "== 3/4 Provider OIDC GitHub (idempotent) =="
# La condition d'attribut RESTREINT l'accès au dépôt autorisé : sans elle,
# n'importe quel dépôt GitHub pourrait usurper l'identité du compte de service.
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
      --project "$PROJECT_ID" --location=global \
      --workload-identity-pool="$POOL_ID" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project "$PROJECT_ID" --location=global \
    --workload-identity-pool="$POOL_ID" \
    --display-name="$PROVIDER_DISPLAY" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'"
else
  echo "Provider $PROVIDER_ID déjà présent."
fi

echo "== 4/4 Autorisation du compte de service pour ce dépôt =="
WIF_PRINCIPAL="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_REPO}"
gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
  --project "$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="$WIF_PRINCIPAL"

WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

cat <<EOF

============================================================
✅ WIF provisionné. Ajoute ces deux secrets dans l'environnement
   GitHub « recaptcha » (Settings → Environments → recaptcha) :

   WIF_PROVIDER
   $WIF_PROVIDER

   WIF_SERVICE_ACCOUNT
   $SERVICE_ACCOUNT_EMAIL

Ensuite, une fois les workflows migrés fusionnés et un déploiement
vérifié au vert, supprime l'ancien secret GOOGLE_CREDENTIALS_B64 et
la clé JSON du compte de service dans la console GCP.
============================================================
EOF
