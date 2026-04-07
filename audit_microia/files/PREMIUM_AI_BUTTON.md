# 🎨 Bouton Premium AI - Documentation

## Vue d'ensemble

Le `PremiumAiButton` est un widget Flutter/Material 3 premium pour l'app Prestō, conçu pour permettre aux utilisateurs de décrire leurs besoins via IA.

### Caractéristiques visuelles

**Couleur & Dégradé**
- Couleur principale: `#1A73E8` (Bleu Presto)
- Dégradé vertical: `#2D84F6` (bleu clair en haut) → `#1A73E8` (bleu profond en bas)
- Création d'un effet de profondeur naturel

**Dimenssions**
- Largeur: 92% de l'écran
- Hauteur: 56px
- Rayon de bordure: 20px (forme de pilule)

**Ombre & Élévation**
- Blur radius: 14px
- Opacité: 18% (15-20%)
- Décalage: (0, 4)
- Crée une ombre douce et professionnelle

**Typographie**
- Police: Titillium Web (semi-bold)
- Taille: 17px (16-18px)
- Couleur: Blanc (#FFFFFF)
- Letter spacing: 0.3
- Texte: "Décrire mon besoin (IA)"

**Icône**
- Icône: `Icons.auto_awesome` (Sparkles ✨)
- Couleur: Blanc
- Taille: 20px
- Position: À gauche du texte

## Utilisation

### Import
```dart
import 'package:presto/widgets/premium_ai_button.dart';
```

### Utilisation basique
```dart
PremiumAiButton(
  onPressed: () {
    // Action à exécuter
  },
)
```

### Avec texte personnalisé
```dart
PremiumAiButton(
  onPressed: _startRecording,
  label: 'Enregistrer votre demande',
)
```

### Avec état de chargement
```dart
PremiumAiButton(
  onPressed: _processAudio,
  label: 'Décrire mon besoin (IA)',
  isLoading: _isProcessing,
)
```

### Avec largeur personnalisée
```dart
PremiumAiButton(
  onPressed: _handlePress,
  width: 0.85, // 85% de la largeur
)
```

### Avec bouton désactivé
```dart
PremiumAiButton(
  onPressed: null, // Désactiver le bouton
  label: 'Décrire mon besoin (IA)',
)
```

## Propriétés

| Propriété | Type | Par défaut | Description |
|-----------|------|-----------|-------------|
| `onPressed` | `dynamic` | Requis | Callback ou Future à exécuter (VoidCallback ou Future<void> Function()) |
| `label` | `String` | `'Décrire mon besoin (IA)'` | Texte affiché sur le bouton |
| `width` | `double` | `0.92` | Largeur relative (0-1) |
| `isLoading` | `bool` | `false` | Affiche le spinner de chargement |

## États du bouton

### 1. État normal
- Affiche l'icône sparkles ✨
- Texte "Décrire mon besoin (IA)"
- Fond bleu avec dégradé
- Prêt à être cliqué

### 2. État chargement
- Remplace l'icône par un spinner
- Texte toujours visible
- Fond bleu inchangé
- Bouton désactivé

### 3. État désactivé
- Bouton grisé
- Aucune interaction possible
- Opacity réduite
- Utilisé quand `onPressed = null`

## Intégration dans main.dart

Le bouton a été intégré dans la section "Je publie une offre" pour permettre aux utilisateurs de décrire leurs besoins:

```dart
// État normal - bouton affichant le sparkles
if (!_isListening)
  PremiumAiButton(
    onPressed: _isAnalyzing ? null : _startMic,
    label: 'Décrire mon besoin (IA)',
    isLoading: _isAnalyzing,
  )

// État d'enregistrement - bouton rouge avec "Arrêter"
else
  _buildMicRecordingButton()
```

### Bouton d'enregistrement alternatif
Quand l'utilisateur enregistre, un bouton rouge s'affiche:
- Couleur: Rouge (#E53935 → #C62828)
- Texte: "Appuyer pour arrêter"
- Icône: Stop circle
- Même style que le bouton principal

## Fonctionnalité

### Gestion des appels asynchrones
Le widget gère automatiquement les fonctions asynchrones:
```dart
PremiumAiButton(
  onPressed: () async {
    await _startMic(); // Future<void>
  },
)
```

Le spinner de chargement s'affiche automatiquement pendant l'exécution.

## Accessibilité

- ✅ Contraste de couleur élevé (WCAG AA)
- ✅ Taille tactile minimale respectée (56px)
- ✅ Ripple effect Material Design
- ✅ Support des gestes longs
- ✅ Indicateur visuel d'état

## Personnalisation

### Modifier la couleur
Pour une version différente (ex. rouge, vert), vous pouvez étendre le widget:

```dart
class CustomAiButton extends PremiumAiButton {
  const CustomAiButton({
    required VoidCallback onPressed,
    Color startColor = const Color(0xFFFF6B6B),
    Color endColor = const Color(0xFFEE5A52),
  }) : super(onPressed: onPressed);
}
```

### Ajouter des animations
Le widget peut être étendu avec:
```dart
// Scale animation au tap
// Rotation animation du sparkles
// Shimmer effect pendant le chargement
```

## Performance

- 🚀 Widget léger et performant
- 📦 Pas de dépendances externes
- 🎨 Utilise Material Design widgets natifs
- ✨ Animations fluides à 60 FPS

## Tests

### Page de démonstration
Consultez `lib/premium_ai_button_preview.dart` pour une démonstration interactive de tous les états du bouton.

### Exécuter la démo
```bash
flutter run -d chrome --target lib/premium_ai_button_preview.dart
```

## Fichiers concernés

- **Widget principal**: [`lib/widgets/premium_ai_button.dart`](lib/widgets/premium_ai_button.dart)
- **Intégration**: [`lib/main.dart`](lib/main.dart) (ligne ~5220)
- **Démonstration**: [`lib/premium_ai_button_preview.dart`](lib/premium_ai_button_preview.dart)

## Changelog

### v1.0.0 (2024-12-20)
- ✅ Création du widget `PremiumAiButton`
- ✅ Intégration dans le formulaire de publication
- ✅ Dégradé vertical professionnel
- ✅ Ombre douce Material Design
- ✅ État de chargement avec spinner
- ✅ Icône sparkles blanche
- ✅ Support des callbacks asynchrones
- ✅ Page de démonstration complète

## Notes de conception

Le bouton a été conçu selon les principes Material Design 3:
- **Couleur**: Bleu Presto cohérent avec l'identité visuelle
- **Forme**: Pilule arrondie pour un style moderne et accueillant
- **Ombre**: Douce et subtile, pas intrusive
- **Typographie**: Semi-bold pour attirer l'attention sans crier
- **Icône**: Sparkles pour évoquer la magie de l'IA
- **Feedback**: Ripple effect et changements d'état clairs

---

📝 Documentation mise à jour: 20 décembre 2024
