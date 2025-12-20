# ✅ Guide de Test - Bouton Premium AI

## 🚀 Démarrage rapide

### 1. Installer les dépendances
```bash
cd /workspaces/presto_app
flutter pub get
```

### 2. Lancer l'application
```bash
# Mode développement (hot reload activé)
flutter run -d chrome

# Ou sur autre appareil
flutter run
```

## 🧪 Scénarios de test

### Test 1: État normal du bouton
**Étapes:**
1. Ouvrir l'app Presto
2. Aller à "Je publie une offre"
3. Scroller jusqu'à la section "Détail de votre besoin"

**Résultats attendus:**
- ✅ Bouton bleu visible avec dégradé haut→bas
- ✅ Icône sparkles (✨) blanche à gauche
- ✅ Texte blanc "Décrire mon besoin (IA)" au centre
- ✅ Ombre douce visible sous le bouton
- ✅ Rayon arrondi (forme de pilule)
- ✅ Largeur ≈ 92% de l'écran
- ✅ Hauteur ≈ 56px

### Test 2: Interaction - Clic du bouton
**Étapes:**
1. Depuis l'écran de publication
2. Cliquer sur le bouton Premium AI
3. Observer le comportement

**Résultats attendus:**
- ✅ Ripple effect blanc apparaît
- ✅ Microphone commence l'enregistrement
- ✅ Le bouton change d'état (état d'enregistrement)

### Test 3: État d'enregistrement
**Étapes:**
1. Bouton a été cliqué (Test 2)
2. Observer le changement du bouton
3. Parler pendant 5-10 secondes

**Résultats attendus:**
- ✅ Bouton devient **rouge** (#E53935 → #C62828)
- ✅ Texte change en "Appuyer pour arrêter"
- ✅ Icône devient "stop_circle" (⏸️)
- ✅ 3 points clignotants apparaissent sous le bouton
- ✅ Texte "Enregistrement en cours..." s'affiche

### Test 4: Arrêt de l'enregistrement
**Étapes:**
1. Depuis l'état d'enregistrement
2. Cliquer sur le bouton rouge "Appuyer pour arrêter"

**Résultats attendus:**
- ✅ L'enregistrement s'arrête
- ✅ Points clignotants disparaissent
- ✅ "Enregistrement en cours..." disparaît
- ✅ Bouton passe en état de **chargement**

### Test 5: État de chargement
**Étapes:**
1. Après arrêt de l'enregistrement
2. L'app traite l'audio (10-20 secondes)

**Résultats attendus:**
- ✅ Spinner blanc apparaît à la place du sparkles
- ✅ Spinner tourne continuellement
- ✅ Texte reste "Décrire mon besoin (IA)"
- ✅ Bouton est désactivé (pas de clic possible)
- ✅ Gradient bleu maintenu

### Test 6: Succès du traitement
**Étapes:**
1. Attendre la fin du traitement IA
2. Observer le remplissage automatique

**Résultats attendus:**
- ✅ Bouton revient à l'état normal (sparkles visible)
- ✅ Spinner disparaît
- ✅ SnackBar confirme "Transcription réussie"
- ✅ Champs du formulaire sont remplis:
   - Titre: Généré par IA
   - Description: Générée par IA
   - Catégorie: Détectée
   - Ville: Extraite

### Test 7: Gestion des erreurs
**Étapes:**
1. Déclencher un enregistrement avec bruit/silence
2. Ou couper la connexion Internet

**Résultats attendus:**
- ✅ SnackBar d'erreur s'affiche
- ✅ Bouton revient à l'état normal
- ✅ Message d'erreur lisible: "Erreur analyse: ..."
- ✅ Utilisateur peut réessayer

### Test 8: Page de démo (Premium AI Button Preview)
**Étapes:**
```bash
flutter run -d chrome --target lib/premium_ai_button_preview.dart
```

**Résultats attendus:**
- ✅ 3 boutons affichés (Normal, Chargement, Désactivé)
- ✅ Chaque état est bien visible
- ✅ Spécifications techniques affichées
- ✅ Exemple de code visible

## 🎨 Vérifications visuelles

### Dégradé
- [ ] Bleu clair en haut (#2D84F6)
- [ ] Bleu profond en bas (#1A73E8)
- [ ] Dégradé lisse et graduel
- [ ] Pas de bandes

### Ombre
- [ ] Ombre visible mais douce
- [ ] Blur : ~14px
- [ ] Opacité : ~18%
- [ ] Décalage vers le bas

### Texte
- [ ] Blanc pur, bien lisible
- [ ] Centré verticalement et horizontalement
- [ ] Semi-bold (600)
- [ ] Taille appropriée (17px)

### Icône
- [ ] Sparkles (✨) blanche
- [ ] 20x20px
- [ ] À gauche du texte
- [ ] Bien espacée (10px du texte)

### Forme
- [ ] Rayon de 20px
- [ ] Pas d'angles aigus
- [ ] Symétrique
- [ ] Forme de pilule

## 📱 Tests responsive

### Petit écran (< 360px)
```
Orientation: Portrait
Largeur: 320px
Bouton largeur: 294px (92%)
```
- [ ] Bouton reste visible entièrement
- [ ] Texte n'est pas tronqué
- [ ] Pas de débordement

### Écran normal (360-800px)
```
Orientation: Portrait ou Paysage
Largeur: 360-800px
Bouton largeur: 330-736px (92%)
```
- [ ] Bouton s'adapte
- [ ] Proportions maintenues
- [ ] Lisibilité parfaite

### Tablette / Grand écran (> 800px)
```
Orientation: Portrait ou Paysage
Largeur: 800px+
Bouton largeur: 92% ou max 400px
```
- [ ] Bouton adapté
- [ ] Pas trop large
- [ ] Centré correctement

## 🔊 Test audio (si applicable)

### Enregistrement audio
- [ ] Micro démarre correctement
- [ ] Audio enregistré en WAV
- [ ] Qualité audio (16-bit, 16kHz ou plus)
- [ ] Fichier temporaire créé

### Transcription
- [ ] Speech-to-Text v1 fonctionne
- [ ] Texte transcrit lisible
- [ ] Correction automatique appliquée
- [ ] Accents français gérés

### Analyse IA
- [ ] OpenAI GPT-4o-mini appelé
- [ ] JSON structuré retourné
- [ ] Champs remplis correctement
- [ ] Format "Je recherche..." respecté

## 🐛 Tests de débogage

### Logs Flutter
```bash
flutter run -v
# Chercher les logs du bouton et de l'enregistrement
```

### Firebase Functions Logs
```bash
firebase functions:log --only generateOfferDraft,transcribeAndDraftOffer
```

### Erreurs courantes
- [ ] `onPressed null` → Bouton désactivé ✓
- [ ] `isLoading = true` → Spinner s'affiche ✓
- [ ] `Future<void>` → Géré automatiquement ✓
- [ ] `VoidCallback` → Également supporté ✓

## ♿ Tests d'accessibilité

### Contraste
```bash
# Vérifier le ratio de contraste
# Bleu #1A73E8 sur Blanc = 8.5:1 (AAA ✓)
# Blanc #FFFFFF sur Bleu = 8.5:1 (AAA ✓)
```

### Sémantique
- [ ] Role du widget: button
- [ ] Label: "Décrire mon besoin (IA)"
- [ ] État cliquable/désactivé clair
- [ ] Feedback au tap

### Navigation
- [ ] Clavier: Tab + Enter fonctionne
- [ ] Screen reader: Label lu correctement
- [ ] Gestures: Tap et long-press supportés

## 📊 Checklist finale

| Catégorie | Vérification | Statut |
|-----------|-------------|--------|
| **Design** | Couleurs correctes | ☐ |
| | Dégradé visible | ☐ |
| | Ombre douce | ☐ |
| | Forme de pilule | ☐ |
| **Texte** | Blanc et centré | ☐ |
| | Semi-bold 17px | ☐ |
| | Lisible | ☐ |
| **Icône** | Sparkles visible | ☐ |
| | Blanche 20x20px | ☐ |
| | Bien positionnée | ☐ |
| **Interaction** | Ripple effect | ☐ |
| | Feedback haptique | ☐ |
| | État chargement | ☐ |
| **Responsive** | Mobile (320px) | ☐ |
| | Tablet (600px) | ☐ |
| | Desktop (1200px) | ☐ |
| **Accessibilité** | Contraste OK | ☐ |
| | Taille tactile OK | ☐ |
| | Screen reader OK | ☐ |
| **Fonctionnalité** | Micro marche | ☐ |
| | Transcription OK | ☐ |
| | Analyse IA OK | ☐ |
| | Champs remplis | ☐ |

## 🔍 Rapporter un bug

Si vous trouvez un bug:

1. **Décrivez le problème** de manière précise
2. **Fournissez des étapes** pour reproduire
3. **Incluez des screenshots** si possible
4. **Mentionnez votre appareil/version Flutter**

Exemple:
```
Titre: Bouton perd son dégradé sur Android
Étapes:
1. Ouvrir l'app sur Android 12
2. Aller à "Je publie une offre"
3. Observer le bouton
Résultat: Dégradé ne s'affiche pas
Attendu: Dégradé bleu visible
Appareil: Pixel 5, Flutter 3.x
```

## 📞 Support

Pour des questions ou des améliorations:
- Consultez [PREMIUM_AI_BUTTON.md](PREMIUM_AI_BUTTON.md)
- Consultez [PREMIUM_AI_BUTTON_DESIGN.md](PREMIUM_AI_BUTTON_DESIGN.md)
- Vérifiez les logs: `firebase functions:log`

---

**Dernière mise à jour**: 20 décembre 2024  
**Version testée**: Flutter 3.x, Material Design 3
