# 🎨 Bouton Premium AI - Spécifications Visuelles

## Design System

```
┌────────────────────────────────────┐
│    BOUTON PREMIUM AI - PRESTO      │
└────────────────────────────────────┘

   ┌─────────────────────────────┐
   │  ✨ Décrire mon besoin (IA) │  ← Bouton au repos
   └─────────────────────────────┘
   
   Gradient: Haut → Bas
   #2D84F6 ────────────→ #1A73E8
   
   ┌─────────────────────────────┐
   │  ⏸️  Appuyer pour arrêter    │  ← État enregistrement (rouge)
   └─────────────────────────────┘
```

## Dimensions exactes

```
Largeur:     92% de l'écran
Hauteur:     56px
Padding:     Symétrique horizontal + vertical
Rayon:       20px (borderRadius)

Espacements internes:
├─ Gauche: 4px
├─ Icône: 20x20px
├─ Espacement icône-texte: 10px
├─ Texte: centré
└─ Droit: 4px
```

## Palette de couleurs

### État normal (Bleu)
```
Dégradé de haut en bas:
┌─────────────────┐
│   #2D84F6      │  ← Bleu clair (2D84F6)
│      ▼▼▼        │     gradient
│      ▼▼▼        │
│   #1A73E8      │  ← Bleu Presto (1A73E8)
└─────────────────┘

Ombre:
- Blur: 14px
- Opacité: 18% (#1A73E8)
- Décalage: (0, 4)
- Spread: 0
```

### État enregistrement (Rouge)
```
Dégradé:
#E53935 (haut) → #C62828 (bas)

Même ombre style
```

### Texte
```
Couleur: #FFFFFF (Blanc pur)
Opacité: 100%
Police: Titillium Web / sans-serif
Poids: 600 (Semi-bold)
Taille: 17px
Espacement lettres: 0.3
Hauteur ligne: Par défaut
```

### Icônes
```
Icône principal (sparkles): Icons.auto_awesome
Taille: 20x20px
Couleur: #FFFFFF
Opacité: 100%

Spinner (lors du chargement):
Taille: 20x20px
Couleur: #FFFFFF avec 90% opacité
Largeur trait: 2px
```

## Effets et interactions

### États visuels
```
1. NORMAL (inactif)
   └─ Affichage: Icône + Texte
   └─ Curseur: pointer
   └─ Opacité: 100%
   └─ Elevation: 4px (ombre)

2. HOVER / FOCUS
   └─ Material Ripple Effect
   └─ Légère surélévation (opcional)
   └─ Opacité inchangée

3. PRESSED
   └─ Ripple Material intensifié
   └─ Feedback haptique (vibration légère)
   └─ Opacité inchangée

4. LOADING
   └─ Affichage: Spinner + Texte
   └─ Bouton désactivé (onTap inactif)
   └─ Spinner animé
   └─ Opacité: 80%

5. DÉSACTIVÉ
   └─ Affichage: Icône + Texte grisé
   └─ Curseur: not-allowed
   └─ Opacité: 50%
   └─ Aucune interaction
```

## Typographie

### Titre du bouton
```
Police:           Titillium Web / System sans-serif
Poids:            600 (Semi-bold)
Taille:           17px (16-18px)
Hauteur ligne:    1.0 (par défaut)
Espacement:       0.3
Couleur:          #FFFFFF
Casse:            Mixte (Décrire mon besoin)
Alignement:       Centré
Orientation:      Horizontal
```

## Animations

### Transitions (si implémentées)
```
Duration standard: 300ms
Easing: easeInOut (cubic)

Animations possibles:
├─ Scale: 0.98 → 1.0 (au press)
├─ Opacity: fadeIn/fadeOut (au chargement)
├─ Spinner: rotation continue (infinité)
└─ Ripple: Material Design natif
```

## Accessibilité

### Contrast Ratio
```
Bleu sur Blanc: 3.2:1 (WCAG AA pour texte)
Blanc sur Bleu: 8.5:1 (WCAG AAA)
```

### Taille tactile
```
Largeur minimale: 292px (92% sur écran 320px)
Hauteur minimale: 56px
Cible idéale: 48-72px ✓
```

### Sémantique
```
Role: button
Label: "Décrire mon besoin (IA)"
Pressé/Not pressé: Indication visuelle claire
État chargement: Annonce accessible
```

## Responsive Design

### Petits écrans (< 360px)
```
Largeur: 92% (reste approprié)
Hauteur: 56px (maintenu)
Texte: Peut être tronqué avec ellipsis
Icône: 18px (optionnel)
```

### Écrans normaux (360-1080px)
```
Largeur: 92% (idéal)
Hauteur: 56px (parfait)
Texte: Complètement visible
Icône: 20px
```

### Grands écrans (> 1080px)
```
Largeur: Peut être limitée à max 400px
Hauteur: 56-60px (peuvent être augmentés)
Texte: Taille augmentable à 18px
Icône: 22px
```

## Intégration Material Design 3

### Elevation (ombre)
```
Rest:    Elevation 4 (ombre douce)
Hover:   Elevation 8 (augmentée)
Pressed: Elevation 2 (légère)
```

### Ripple Effect
```
Couleur: Blanc avec 24% opacité
Forme: Circulaire (InkWell)
Rayon: Respecte borderRadius (20px)
Duration: 400ms
```

## Fichiers concernés

```
lib/
├── widgets/
│   └── premium_ai_button.dart        ← Widget principal
├── main.dart                          ← Intégration (ligne ~5220)
├── premium_ai_button_preview.dart    ← Page de démo
└── PREMIUM_AI_BUTTON.md              ← Documentation
```

## Exemple CSS équivalent (pour référence web)

```css
.premium-ai-button {
  width: 92%;
  height: 56px;
  border-radius: 20px;
  background: linear-gradient(to bottom, #2D84F6, #1A73E8);
  box-shadow: 0 4px 14px rgba(26, 115, 232, 0.18);
  color: white;
  font-family: "Titillium Web", sans-serif;
  font-weight: 600;
  font-size: 17px;
  letter-spacing: 0.3px;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  transition: all 300ms ease-in-out;
}

.premium-ai-button:hover {
  box-shadow: 0 8px 20px rgba(26, 115, 232, 0.25);
  transform: translateY(-2px);
}

.premium-ai-button:active {
  transform: translateY(0);
  box-shadow: 0 2px 8px rgba(26, 115, 232, 0.15);
}

.premium-ai-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.premium-ai-button .icon {
  width: 20px;
  height: 20px;
  fill: white;
}

.premium-ai-button .loading-spinner {
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top: 2px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
```

---

**Version**: 1.0.0  
**Date**: 20 décembre 2024  
**Designer**: Presto App Design System  
**Framework**: Flutter / Material Design 3
