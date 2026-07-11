#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-main}"
base_remote_ref="origin/${base_ref}"

if ! git rev-parse --verify "${base_remote_ref}" >/dev/null 2>&1; then
  echo "Référence de base introuvable: ${base_remote_ref}" >&2
  exit 2
fi

mapfile -t dart_files < <(
  git diff --name-only --diff-filter=ACMR "${base_remote_ref}...HEAD" -- '*.dart' \
    | while IFS= read -r path; do
        [[ -f "${path}" ]] && printf '%s\n' "${path}"
      done
)

if [[ ${#dart_files[@]} -eq 0 ]]; then
  echo 'Aucun fichier Dart modifié : contrôle de formatage ignoré.'
  exit 0
fi

echo "Contrôle du formatage de ${#dart_files[@]} fichier(s) Dart modifié(s)."
dart format --output=none --set-exit-if-changed "${dart_files[@]}"
