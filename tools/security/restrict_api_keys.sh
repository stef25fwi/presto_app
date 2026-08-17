#!/usr/bin/env bash
#
# Pose les restrictions d'application manquantes sur les clés API de
# production, constat du 17/08/2026 : les 7 clés n'en portaient aucune
# (docs/evidence/security/api-key-restrictions.md).
#
# À exécuter depuis Cloud Shell, déjà authentifié sur le projet.
# Par défaut le script n'applique RIEN : il imprime les commandes.
#
#   bash tools/security/restrict_api_keys.sh          # simulation
#   APPLY=1 bash tools/security/restrict_api_keys.sh  # exécution réelle
#
# Les identifiants ci-dessous proviennent du relevé du 17/08/2026. Si des
# clés ont été créées ou supprimées depuis, relancer d'abord :
#   gcloud services api-keys list --project=presto-app-74abe --format=json
#
set -euo pipefail

PROJECT="presto-app-74abe"
APPLY="${APPLY:-0}"

# UID relevés le 17/08/2026.
KEY_BROWSER_2026="e489e9b6-ea2a-4634-9f48-1fd96ad6a19b" # créée 15/04/2026
KEY_BROWSER_2025="22d51620-5b04-490f-911e-9042a93a64a2" # créée 22/11/2025
KEY_ANDROID="83512e8a-3c39-496f-b3a8-1dbddacdf97e"
KEY_IOS="187a10af-5395-4c40-a949-6920e8905082"
KEY_PLACES="63c4c266-c0ec-44bf-b837-f39e33346749"
KEY_GEMINI="200c59cd-42c3-4136-9c61-8f673b2ec9e6"
KEY_VERTEX="69445b21-c1d7-4a51-94d8-18dc90869035"

# Empreinte de signature relevée dans android/app/google-services.json pour
# fr.ilipresto.app. Voir l'étape 4 : elle est probablement incomplète.
SHA1_KNOWN="37C41A3947967A59E3EFBD21E67C97D75FDCDD62"

run() {
  echo
  echo "  \$ $*"
  if [ "$APPLY" = "1" ]; then
    "$@"
  fi
}

if [ "$APPLY" != "1" ]; then
  echo "=== SIMULATION — rien ne sera modifié. APPLY=1 pour exécuter. ==="
fi

# ---------------------------------------------------------------------------
# Étape 0 — OBLIGATOIRE : identifier les deux clés navigateur
# ---------------------------------------------------------------------------
# Deux « Browser key (auto created by Firebase) » coexistent. L'app web en
# production utilise AIzaSyCXzhQcvF… (lib/firebase_options.dart) ; l'autre,
# AIzaSyB-Oo_86V…, n'apparaissait que dans un build figé sous docs/.
#
# `api-keys list` ne renvoie PAS le matériel des clés : l'association
# UID -> clé n'a donc pas pu être établie depuis le relevé, seulement
# supposée par date de création. NE PAS supprimer une clé avant d'avoir
# confronté les deux sorties ci-dessous.
echo
echo "### Étape 0 — identifier les clés navigateur (à faire en premier)"
run gcloud services api-keys get-key-string "$KEY_BROWSER_2026" --project="$PROJECT"
run gcloud services api-keys get-key-string "$KEY_BROWSER_2025" --project="$PROJECT"
echo
echo "  Celle qui vaut AIzaSyCXzhQcvF… est la clé VIVE : la restreindre (étape 1)."
echo "  L'autre est la clé PÉRIMÉE : la supprimer (étape 5)."

# ---------------------------------------------------------------------------
# Étape 1 — clé navigateur vive : référents HTTP
# ---------------------------------------------------------------------------
# AVERTISSEMENT : une liste incomplète casse la connexion Google en
# production. Le domaine du gestionnaire d'authentification Firebase doit y
# figurer même si `authDomain` vaut ilipresto.fr, un flux OAuth par
# popup/redirection pouvant encore l'emprunter. À faire hors heure de
# pointe, puis tester immédiatement une connexion Google réelle.
echo
echo "### Étape 1 — restreindre la clé navigateur VIVE (adapter l'UID si l'étape 0 l'infirme)"
run gcloud services api-keys update "$KEY_BROWSER_2026" \
  --project="$PROJECT" \
  --allowed-referrers="https://ilipresto.fr/*,https://www.ilipresto.fr/*,https://presto-app-74abe.firebaseapp.com/*,https://presto-app-74abe.web.app/*,https://ilipresto.web.app/*,https://ilipresto.firebaseapp.com/*"

# ---------------------------------------------------------------------------
# Étape 2 — clé Android : package + empreinte
# ---------------------------------------------------------------------------
echo
echo "### Étape 2 — restreindre la clé Android"
run gcloud services api-keys update "$KEY_ANDROID" \
  --project="$PROJECT" \
  --allowed-application="sha1_fingerprint=$SHA1_KNOWN,package_name=fr.ilipresto.app"

# ---------------------------------------------------------------------------
# Étape 3 — clé iOS : bundle ID
# ---------------------------------------------------------------------------
echo
echo "### Étape 3 — restreindre la clé iOS"
run gcloud services api-keys update "$KEY_IOS" \
  --project="$PROJECT" \
  --allowed-bundle-ids="fr.ilipresto.app"

# ---------------------------------------------------------------------------
# Étape 4 — empreinte de signature Play (décision humaine requise)
# ---------------------------------------------------------------------------
# fr.ilipresto.app ne porte qu'une empreinte dans google-services.json, là où
# l'ancien com.presto.app en porte deux. Si SHA1_KNOWN est l'empreinte
# d'upload, l'app installée depuis le Play Store sera rejetée.
#
# Relever l'empreinte de signature Play dans :
#   Play Console -> Configuration -> Intégrité de l'app -> Signature de l'app
# puis rejouer l'étape 2 avec les DEUX --allowed-application :
#
#   gcloud services api-keys update "$KEY_ANDROID" --project="$PROJECT" \
#     --allowed-application="sha1_fingerprint=<UPLOAD>,package_name=fr.ilipresto.app" \
#     --allowed-application="sha1_fingerprint=<PLAY>,package_name=fr.ilipresto.app"
#
# Ajouter aussi l'empreinte Play côté Firebase (Paramètres du projet -> Vos
# applications -> Android -> Ajouter une empreinte), sans quoi Google
# Sign-In échouera indépendamment de la clé API.
echo
echo "### Étape 4 — empreinte Play à relever manuellement (voir commentaires)"

# ---------------------------------------------------------------------------
# Étape 5 — clés inutilisées : vérifier puis supprimer
# ---------------------------------------------------------------------------
# Aucune référence à places-backend ni à generativelanguage n'a été trouvée
# dans functions/src, lib ni tools ; google_api.ts passe par GoogleAuth/OAuth,
# pas par une clé API. Ces clés portent des APIs facturées à l'usage et
# n'ont aucune restriction : c'est le risque le plus concret du relevé.
#
# Vérifier l'absence de trafic avant de supprimer :
#   Console GCP -> API et services -> Tableau de bord -> places-backend
# Une suppression de clé est IRRÉVERSIBLE. Décommenter en connaissance de cause.
echo
echo "### Étape 5 — clés candidates à la suppression (commentées, à confirmer)"
echo "  # gcloud services api-keys delete $KEY_PLACES --project=$PROJECT"
echo "  # gcloud services api-keys delete $KEY_GEMINI --project=$PROJECT"
echo "  # gcloud services api-keys delete <UID de la clé navigateur PÉRIMÉE> --project=$PROJECT"
echo
echo "  Si places-server-prod sert encore, la restreindre par IP plutôt que la supprimer :"
echo "  # gcloud services api-keys update $KEY_PLACES --project=$PROJECT --allowed-ips=<IP1>,<IP2>"

# ---------------------------------------------------------------------------
# Étape 6 — contrôle final
# ---------------------------------------------------------------------------
echo
echo "### Étape 6 — revérifier, puis reporter la sortie dans le document de preuve"
run gcloud services api-keys list --project="$PROJECT" \
  --format="table(displayName, restrictions.browserKeyRestrictions.allowedReferrers, restrictions.androidKeyRestrictions.allowedApplications, restrictions.iosKeyRestrictions.allowedBundleIds, restrictions.serverKeyRestrictions.allowedIps)"

echo
echo "Une fois toutes les clés restreintes : mettre api-keys-restricted à"
echo "\"verified\" dans quality/security-controls.json et joindre le nouveau"
echo "relevé daté à docs/evidence/security/api-key-restrictions.md."
