#!/usr/bin/env bash
# Finalise le nettoyage post-incident après la révocation de la clé
# github-firebase-deploy / 6a7e6b64... et la migration Workload Identity
# Federation (déjà mergée dans main).
#
# À lancer dans Cloud Shell (gcloud déjà authentifié dessus).
# Chaque section est indépendante : relis les commentaires avant d'exécuter
# les étapes destructives (suppression de clés).

set -uo pipefail
PROJECT_ID=presto-app-74abe

echo "############################################"
echo "1/4 — Audit d'activité pendant la fenêtre d'exposition"
echo "############################################"
echo "Ajuste --freshness si l'exposition remonte à plus de 30 jours."
gcloud logging read '
  protoPayload.authenticationInfo.principalEmail="github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com"
' \
  --project="$PROJECT_ID" \
  --freshness=30d \
  --format="table(timestamp, protoPayload.methodName, protoPayload.resourceName, protoPayload.requestMetadata.callerIp)" \
  --limit=200

echo
echo "-> Relis la liste ci-dessus : cherche des déploiements, accès Storage/"
echo "   Firestore ou changements IAM que TU n'as pas déclenchés toi-même via"
echo "   le workflow GitHub Actions (les runs légitimes viennent des runners"
echo "   GitHub, callerIp variable mais methodName cohérent avec un déploiement)."
echo

echo "############################################"
echo "2/4 — Supprimer la 2e clé sur github-firebase-deploy (ead09a43...)"
echo "############################################"
echo "Plus aucune clé n'est nécessaire sur ce compte depuis la migration WIF."
read -p "Confirmer la suppression de la clé ead09a43... ? (o/N) " confirm
if [[ "$confirm" == "o" || "$confirm" == "O" ]]; then
  gcloud iam service-accounts keys delete ead09a43c967b3245334073f5eabcb806c702e1b \
    --iam-account=github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com \
    --project="$PROJECT_ID" --quiet
  echo "Vérification : "
  gcloud iam service-accounts keys list \
    --iam-account=github-firebase-deploy@presto-app-74abe.iam.gserviceaccount.com \
    --project="$PROJECT_ID"
else
  echo "Ignoré."
fi

echo
echo "############################################"
echo "3/4 — Comptes à risque repérés dans les captures (VÉRIFIER avant suppression)"
echo "############################################"
echo "-- Clé App Engine par défaut (rôle Éditeur, large) --"
gcloud iam service-accounts keys list \
  --iam-account=presto-app-74abe@appspot.gserviceaccount.com \
  --project="$PROJECT_ID"
echo "Ne supprime la clé 20cd3cf5... que si tu es certain qu'aucun service ne"
echo "l'utilise (ancien script, Cloud Run/Functions, intégration externe)."
echo "Commande si confirmé :"
echo "  gcloud iam service-accounts keys delete 20cd3cf53da531aa21b44b1cb661804bd65 \\"
echo "    --iam-account=presto-app-74abe@appspot.gserviceaccount.com --project=$PROJECT_ID"
echo
echo "-- Compte github-deploy ('ilipresto github claude'), clé a4bdcf3c... --"
gcloud iam service-accounts keys list \
  --iam-account=github-deploy@presto-app-74abe.iam.gserviceaccount.com \
  --project="$PROJECT_ID"
echo "Ce compte n'est PAS celui utilisé par les workflows GitHub Actions du"
echo "dépôt presto_app (ceux-ci utilisent github-firebase-deploy). Identifie"
echo "d'abord ce qui l'utilise avant de le désactiver/supprimer :"
echo "  gcloud logging read 'protoPayload.authenticationInfo.principalEmail=\"github-deploy@presto-app-74abe.iam.gserviceaccount.com\"' --project=$PROJECT_ID --freshness=30d --limit=50"

echo
echo "############################################"
echo "4/4 — Empêcher toute recréation future de clé (org policy)"
echo "############################################"
read -p "Activer iam.disableServiceAccountKeyCreation sur ce projet ? (o/N) " confirm2
if [[ "$confirm2" == "o" || "$confirm2" == "O" ]]; then
  if gcloud resource-manager org-policies enable-enforce \
       iam.disableServiceAccountKeyCreation --project="$PROJECT_ID"; then
    echo "Activé. Toute tentative future de créer une clé JSON échouera par défaut."
  else
    echo "ÉCHEC — la commande a renvoyé une erreur (voir ci-dessus, souvent un"
    echo "droit orgpolicy.policyAdmin manquant). La policy N'EST PAS active."
    echo "Vérifie ton rôle avec :"
    echo "  gcloud projects get-iam-policy $PROJECT_ID --flatten=\"bindings[].members\" \\"
    echo "    --filter=\"bindings.members:\$(gcloud config get-value account)\" \\"
    echo "    --format=\"table(bindings.role)\""
  fi
else
  echo "Ignoré."
fi

echo
echo "Terminé. Étape restante non automatisable ici : supprimer le secret"
echo "GOOGLE_CREDENTIALS_B64 dans GitHub -> Settings -> Environments ->"
echo "recaptcha -> Secrets (bloqué depuis cet agent par la politique du proxy)."
