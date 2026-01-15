#!/bin/bash
# Script pour lancer l'application web Flutter

echo "🚀 Lancement de l'application Flutter Web sur le port 8080..."
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
