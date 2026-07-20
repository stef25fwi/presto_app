#!/usr/bin/env bash
# Purge les logs de tous les runs des workflows ayant exposé des credentials
# décodés dans leurs dumps env: (voir correctif add-mask dans les workflows).
#
# Prérequis : gh CLI authentifié avec un compte admin du dépôt.
# Usage : bash tools/security/purge_workflow_run_logs.sh [owner/repo]
#
# La suppression des logs est irréversible mais ne supprime pas les runs
# eux-mêmes (historique et artefacts conservés).

set -euo pipefail

REPO="${1:-stef25fwi/presto_app}"
WORKFLOWS=("deploy.yml" "build_apk.yml" "microia-timings.yml")

for wf in "${WORKFLOWS[@]}"; do
  echo "== Workflow $wf =="
  page=1
  total=0
  while :; do
    ids=$(gh api "repos/$REPO/actions/workflows/$wf/runs?per_page=100&page=$page" \
      --jq '.workflow_runs[].id') || break
    [ -z "$ids" ] && break
    for id in $ids; do
      if gh api -X DELETE "repos/$REPO/actions/runs/$id/logs" >/dev/null 2>&1; then
        total=$((total + 1))
      fi
      # 410/404 = logs déjà purgés ou expirés : on continue.
    done
    echo "  page $page traitée (cumul: $total logs purgés)"
    page=$((page + 1))
  done
  echo "  -> $total logs purgés pour $wf"
done

echo "Terminé. Vérifier ensuite qu'aucun nouveau run n'imprime les credentials."
