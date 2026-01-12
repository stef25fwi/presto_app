#!/bin/bash

# Script d'initialisation de la configuration Splashscreen dans Firestore
# Usage: ./init_splashscreen_config.sh

echo "🎨 Initialisation de la configuration Splashscreen..."

# Utiliser Firebase CLI pour créer le document
firebase firestore:set config/splashscreen <<EOF
{
  "active": "v1",
  "updatedAt": {
    "__time__": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
}
EOF

if [ $? -eq 0 ]; then
  echo "✅ Configuration Splashscreen initialisée avec succès!"
  echo "   - Splashscreen actif: V1 (défaut)"
  echo "   - Accès admin: Profil > Espace Admin > Splashscreen"
else
  echo "❌ Erreur lors de l'initialisation"
  exit 1
fi
