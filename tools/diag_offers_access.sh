#!/usr/bin/env bash
# Presto — Diagnostic "annonces ne chargent pas"
# Ramasse les infos utiles cote serveur (indexes, rules, functions, build/deploy).

set -u
PROJECT="presto-app-74abe"

section() { printf '\n\033[1;34m=== %s ===\033[0m\n' "$1"; }

section "Projet Firebase"
firebase use 2>/dev/null || true
echo "(cible attendue: $PROJECT)"

section "Auth utilisateur (firebase login:list)"
firebase login:list 2>/dev/null || true

section "Derniers commits (5)"
git --no-pager log --oneline -5

section "Etat git"
git status --short

section "Indexes Firestore composites"
gcloud firestore indexes composite list --project="$PROJECT" --format="table(name.basename(),queryScope,fields.fieldPath:label=FIELDS,state)" 2>&1 | head -80 || true

section "firestore.rules — extraits offers/listings"
grep -nE "match /(offers|listings|public_offers)\b|isPublicOffer|isPublicListing" firestore.rules | head -40 || true

section "Extensions Flutter/App Check"
grep -nE "appCheck|ReCaptcha|activate" lib/main.dart | head -20 || true

section "Build web artefact"
if [ -d build/web ]; then
  ls -lh build/web/main.dart.js 2>/dev/null | awk '{print $5, $9}'
  echo "build/web/version.json:"
  cat build/web/version.json 2>/dev/null || echo "(absent)"
else
  echo "(build/web absent — lance 'flutter build web --release')"
fi

section "Hosting deploy release (dernier)"
firebase hosting:channel:list --project="$PROJECT" 2>&1 | head -20 || true

section "Cloud Functions logs (marketplace/offers, 50 lignes)"
firebase functions:log --project="$PROJECT" -n 50 2>&1 | grep -iE "offer|listing|permission|unauthenticated|deadline" | head -30 || true

section "FIN"
echo "Copie toute la sortie ci-dessus et envoie-la dans le chat."
