#!/bin/bash
set -euo pipefail

# Déploie l'app Flutter Web sur GitHub Pages (docs/)
# Prérequis: Flutter installé, droits push sur le repo, Pages configuré sur main/docs

cd "$(dirname "$0")"

bash build_web_github_pages.sh

# Assurer les artefacts requis pour GH Pages
pushd docs >/dev/null
  touch .nojekyll
  if [[ -f index.html ]]; then
    cp -f index.html 404.html
  fi
popd >/dev/null

SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Commit & push docs
if ! git diff --quiet -- docs || ! git diff --cached --quiet -- docs; then
  git add -A docs
  git commit -m "docs: publish GH Pages build ($SHA $BRANCH $TS)" || true
  git push
else
  echo "ℹ️  Aucun changement à publier dans docs/"
fi

echo "✅ Déploiement GH Pages terminé. Ouvrir: https://stef25fwi.github.io/presto_app/"
