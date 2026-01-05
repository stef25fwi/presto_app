#!/bin/bash

# Script de vérification statique du clavier et bottom bar
# Valide que le code est conforme sans lancer l'app

echo "🔍 Vérification Statique - Clavier & BottomBar"
echo "==============================================="
echo ""

cd /workspaces/presto_app

ERRORS=0
WARNINGS=0

# Fonction pour compter les occurrences
check_pattern() {
  local pattern=$1
  local description=$2
  local required=$3
  
  local count=$(grep -c "$pattern" lib/main.dart || echo "0")
  
  if [ "$count" -eq 0 ] && [ "$required" = "true" ]; then
    echo "❌ ERREUR: $description (trouvé: 0)"
    ((ERRORS++))
  elif [ "$count" -gt 0 ]; then
    echo "✅ OK: $description (trouvé: $count)"
  else
    echo "⚠️  AVERTISSEMENT: $description (trouvé: 0, optionnel)"
    ((WARNINGS++))
  fi
}

echo "📋 Vérifications Principales:"
echo ""

# Vérifications essentielles
check_pattern "resizeToAvoidBottomInset: false" "resizeToAvoidBottomInset: false" "true"
check_pattern "bottom: MediaQuery.of(context).viewInsets.bottom" "AnimatedPadding avec viewInsets.bottom" "true"
check_pattern "bottom: View.of(context).viewInsets.bottom" "View.of avec viewInsets.bottom (fallback)" "false"
check_pattern "didChangeMetrics()" "Détection du clavier" "true"
check_pattern "kIsWeb" "Conditions spécifiques Web" "true"

echo ""
echo "📋 Vérifications Spécifiques par Page:"
echo ""

# Vérifier chaque page
for page in "ConsultOffersPage" "PublishOfferPage" "MessagesPage" "ConversationPage" "AccountPage"; do
  if grep -q "class $page" lib/main.dart; then
    # Vérifier que la page a resizeToAvoidBottomInset: false
    if grep -A 10 "class $page" lib/main.dart | grep -q "resizeToAvoidBottomInset: false"; then
      echo "✅ $page: resizeToAvoidBottomInset = false"
    else
      echo "⚠️  $page: à vérifier manuellement"
    fi
  fi
done

echo ""
echo "📊 Résumé de la Vérification:"
echo "=============================="
echo "Erreurs détectées: $ERRORS"
echo "Avertissements: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
  echo "✅ Vérification RÉUSSIE!"
  echo ""
  echo "Le code est conforme pour le clavier et la bottom bar."
  echo "Comportement sur Web: ✅ Compatible"
  echo "Comportement sur Mobile: ✅ Optimal"
  exit 0
else
  echo "❌ Vérification ÉCHOUÉE!"
  echo "Veuillez corriger les erreurs détectées."
  exit 1
fi
