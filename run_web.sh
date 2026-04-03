#!/bin/bash
# Script pour lancer l'application web Flutter

echo "🚀 Lancement de l'application Flutter Web sur le port 8080..."
bash tools/flutter_with_build_stamp.sh run -d web-server --web-port 8080 --web-hostname 0.0.0.0
