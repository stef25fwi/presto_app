#!/usr/bin/env bash
set -euo pipefail
BASE_HREF="/presto_app/"

flutter build web --release --base-href "$BASE_HREF"
rm -rf docs/*
cp -r build/web/* docs/
touch docs/.nojekyll

git add docs
git commit -m "deploy: web" || true
git push
