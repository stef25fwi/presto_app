#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="audit_microia"
FILES_DIR="$OUT_DIR/files"
SUMMARY_FILE="$OUT_DIR/00_summary.txt"
INDEX_FILE="$OUT_DIR/files_index.txt"

echo "==> Création du dossier d'audit..."
mkdir -p "$FILES_DIR"

echo "==> Génération du résumé..."
{
  echo "=============================================="
  echo "AUDIT MICROIA / OPENAI / AUDIO / TRANSCRIPTION"
  echo "=============================================="
  echo
  echo "Date: $(date)"
  echo "Repo: $(pwd)"
  echo

  echo "=== A. OCCURRENCES MICROIA / OPENAI / AUDIO ==="
  grep -RniE "MicroIA|microia|micro_ia|micro ia|ai service|ia service|openai|chatgpt|speech|transcri|audio|record|recorder|microphone" \
    lib test web functions backend . \
    --exclude-dir=build \
    --exclude-dir=.dart_tool \
    --exclude-dir=node_modules \
    --exclude-dir=ios/Pods \
    --exclude-dir=android/.gradle \
    --exclude-dir=.git \
    2>/dev/null || true

  echo
  echo "=== B. PUBSPEC ==="
  if [ -f pubspec.yaml ]; then
    cat pubspec.yaml
  else
    echo "pubspec.yaml introuvable"
  fi

  echo
  echo "=== C. ENV / DART-DEFINES / SECRETS ==="
  grep -RniE "API_KEY|OPENAI|MICROIA|SECRET|dart-define|String.fromEnvironment|dotenv|env|functions:secrets:set" \
    . \
    --exclude-dir=build \
    --exclude-dir=.dart_tool \
    --exclude-dir=node_modules \
    --exclude-dir=ios/Pods \
    --exclude-dir=android/.gradle \
    --exclude-dir=.git \
    2>/dev/null || true

  echo
  echo "=== D. HTTP / DIO / APPELS RÉSEAU ==="
  grep -RniE "http\.|Dio\(|BaseOptions|post\(|get\(|put\(|patch\(|delete\(|MultipartFile|FormData|Authorization|Bearer|application/json|multipart/form-data" \
    lib functions backend . \
    --exclude-dir=build \
    --exclude-dir=.dart_tool \
    --exclude-dir=node_modules \
    --exclude-dir=ios/Pods \
    --exclude-dir=android/.gradle \
    --exclude-dir=.git \
    2>/dev/null || true

  echo
  echo "=== E. AUDIO / STT / RECORD / TRANSCRIPTION ==="
  grep -RniE "record|recorder|audio|speech_to_text|transcription|transcribe|microphone|just_audio|audioplayers|flutter_sound|ffmpeg" \
    lib functions backend . \
    --exclude-dir=build \
    --exclude-dir=.dart_tool \
    --exclude-dir=node_modules \
    --exclude-dir=ios/Pods \
    --exclude-dir=android/.gradle \
    --exclude-dir=.git \
    2>/dev/null || true

  echo
  echo "=== F. ARBORESCENCE FICHIERS POSSIBLEMENT UTILES ==="
  find lib functions backend web test \
    \( -name "*.dart" -o -name "*.ts" -o -name "*.js" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) \
    2>/dev/null | sort || true

} > "$SUMMARY_FILE"

echo "==> Copie des fichiers concernés..."
python3 - << 'PY'
import os
import re
import shutil

root = "."
out = "audit_microia/files"
index_file = "audit_microia/files_index.txt"

patterns = [
    r"MicroIA", r"microia", r"micro_ia", r"openai",
    r"speech", r"transcri", r"audio", r"record", r"recorder",
    r"microphone", r"String\.fromEnvironment", r"dotenv",
    r"Authorization", r"Bearer", r"MultipartFile", r"FormData"
]

skip_dirs = {
    ".git", "build", ".dart_tool", "node_modules",
    "Pods", ".gradle", ".idea", "audit_microia"
}

wanted_ext = {".dart", ".ts", ".js", ".json", ".yaml", ".yml", ".md"}

matched = []

for base, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    for f in files:
        ext = os.path.splitext(f)[1].lower()
        if ext not in wanted_ext:
            continue
        path = os.path.join(base, f)
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                content = fh.read()
            if any(re.search(p, content, re.IGNORECASE) for p in patterns):
                matched.append(path)
        except Exception:
            pass

matched = sorted(set(matched))

for path in matched:
    safe_path = path.lstrip("./")
    dest = os.path.join(out, safe_path)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    try:
        shutil.copy2(path, dest)
    except Exception:
        pass

with open(index_file, "w", encoding="utf-8") as f:
    for p in matched:
        f.write(p + "\n")

print(f"{len(matched)} fichiers indexés.")
PY

echo "==> Création d'une archive..."
tar -czf "$OUT_DIR.tar.gz" "$OUT_DIR"

echo
echo "=============================================="
echo "AUDIT TERMINÉ"
echo "=============================================="
echo "Résumé        : $SUMMARY_FILE"
echo "Index fichiers: $INDEX_FILE"
echo "Archive       : $OUT_DIR.tar.gz"
echo
echo "Envoie-moi au minimum :"
echo "1. audit_microia/00_summary.txt"
echo "2. audit_microia/files_index.txt"
echo "3. les fichiers les plus importants listés dans l'index"
echo
echo "Ou, plus simple : envoie directement l'archive $OUT_DIR.tar.gz si tu peux."
