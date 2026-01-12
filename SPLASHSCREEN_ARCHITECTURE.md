# 🏗️ Architecture du Système de Gestion des Splashscreens

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                         UTILISATEUR                              │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Lance l'app
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SPLASHSCREEN LOADER                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  1. Lecture de /config/splashscreen depuis Firestore     │   │
│  │  2. Récupération du champ 'active' (v1, v2 ou v3)       │   │
│  │  3. Affichage du splashscreen correspondant              │   │
│  │  4. Initialisation de l'app (2 secondes minimum)        │   │
│  │  5. Navigation vers HomePage                             │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Affiche
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SPLASHSCREEN WIDGET                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ V1 Original  │  │  V2 Moderne  │  │V3 Minimaliste│          │
│  │  ⭐ Orange   │  │  ✨ Bleu     │  │ 📈 Violet    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Flux Administrateur

```
┌─────────────────────────────────────────────────────────────────┐
│                      ADMINISTRATEUR                              │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Accède à l'admin
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN SPACE PAGE                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  GridView avec tuiles:                                   │   │
│  │  • Utilisateurs                                          │   │
│  │  • Offres                                                │   │
│  │  • Messages                                              │   │
│  │  • Modération                                            │   │
│  │  • Premium                                               │   │
│  │  • Remote Config                                         │   │
│  │  • Streaming                                             │   │
│  │  • 📚 SPLASHSCREEN ← Nouvelle tuile                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Clic sur tuile
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│            SPLASHSCREEN MANAGEMENT PAGE                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  En-tête informatif                                      │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ ℹ️ Sélectionne le splashscreen à afficher au      │  │   │
│  │  │   démarrage de l'application                       │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                           │   │
│  │  Liste des versions:                                     │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ ⭐ Splashscreen V1          [✓ Actif]  [Toggle ON] │  │   │
│  │  │ Version originale...                               │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ ✨ Splashscreen V2                    [Toggle OFF]│  │   │
│  │  │ Version moderne...                                 │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ 📈 Splashscreen V3                    [Toggle OFF]│  │   │
│  │  │ Version minimaliste...                             │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Active un toggle
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FIRESTORE UPDATE                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Collection: /config                                     │   │
│  │  Document: splashscreen                                  │   │
│  │  {                                                       │   │
│  │    "active": "v2",                                      │   │
│  │    "updatedAt": Timestamp                               │   │
│  │  }                                                       │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        │ Confirmation
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SNACKBAR                                     │
│  "Splashscreen V2 activé avec succès !"                         │
└─────────────────────────────────────────────────────────────────┘
```

## Structure Firestore

```
Firestore Database
│
├── /admins/{userId}
│   └── { enabled: true }        ← Requis pour accéder à l'admin
│
└── /config
    └── /splashscreen            ← Configuration globale
        ├── active: "v1"         ← ID du splashscreen actif
        └── updatedAt: Timestamp ← Date de modification
```

## Règles de Sécurité Firestore

```javascript
match /config/{configDoc} {
  allow read: if true;           // ✅ Lecture publique
  allow write: if isAdmin();     // ✅ Écriture admin uniquement
}

function isAdmin() {
  return isSignedIn()
    && exists(/databases/$(database)/documents/admins/$(uid()))
    && (get(/databases/$(database)/documents/admins/$(uid())).data.enabled != false);
}
```

## Flux de Données

```
┌─────────────┐
│   ADMIN     │ Active V2
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│  SPLASHSCREEN MANAGEMENT PAGE       │
│  _setActiveSplashscreen("v2")       │
└──────┬──────────────────────────────┘
       │
       │ Firestore.set()
       ▼
┌─────────────────────────────────────┐
│         FIRESTORE                   │
│  /config/splashscreen               │
│  { active: "v2" }                   │
└──────┬──────────────────────────────┘
       │
       │ Lecture au démarrage
       ▼
┌─────────────────────────────────────┐
│    SPLASHSCREEN LOADER              │
│  _loadSplashscreenConfig()          │
│  _activeSplash = "v2"               │
└──────┬──────────────────────────────┘
       │
       │ _getSplashscreenWidget()
       ▼
┌─────────────────────────────────────┐
│    SPLASHSCREEN V2                  │
│  Affichage à l'écran                │
└─────────────────────────────────────┘
```

## États du Toggle

```
┌────────────────────────────────────────────────────────────┐
│                    ÉTAT INITIAL                            │
│  V1: [ON]  ← active = "v1"                                │
│  V2: [OFF]                                                 │
│  V3: [OFF]                                                 │
└────────────────────────────────────────────────────────────┘
                        │
                        │ Admin active V2
                        ▼
┌────────────────────────────────────────────────────────────┐
│                 TRANSITION                                 │
│  1. _setActiveSplashscreen("v2")                          │
│  2. Firestore update                                       │
│  3. setState() → rebuild                                   │
└────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────────┐
│                  NOUVEL ÉTAT                               │
│  V1: [OFF]                                                 │
│  V2: [ON]  ← active = "v2" + Badge "Actif"               │
│  V3: [OFF]                                                 │
└────────────────────────────────────────────────────────────┘
```

## Composants Clés

### 1. SplashscreenManagementPage
```dart
Responsabilités:
- Charger la config depuis Firestore
- Afficher les versions disponibles
- Gérer les toggles
- Sauvegarder les changements
- Afficher les feedbacks
```

### 2. _SplashscreenCard
```dart
Responsabilités:
- Afficher une version
- Gérer le toggle
- Afficher le badge "Actif"
- Appliquer les styles thématiques
```

### 3. SplashscreenLoader (à implémenter)
```dart
Responsabilités:
- Lire la config Firestore
- Choisir le bon widget
- Gérer le timing (2s min)
- Naviguer vers HomePage
```

## Hiérarchie des Widgets

```
MaterialApp
└── SplashscreenLoader
    ├── SplashscreenV1 (si active = "v1")
    ├── SplashscreenV2 (si active = "v2")
    ├── SplashscreenV3 (si active = "v3")
    └── HomePage (après loading)

AdminSpacePage
└── GridView
    └── _KpiTile (Splashscreen)
        └── Navigator.push
            └── SplashscreenManagementPage
                └── Column
                    └── _SplashscreenCard (x3)
                        ├── Icon
                        ├── Text
                        ├── Badge (si actif)
                        └── Switch
```

## Cycle de Vie

```
1. APP START
   └→ SplashscreenLoader.initState()
      └→ _loadSplashscreenConfig()
         └→ Firestore.get('/config/splashscreen')
            └→ setState(_activeSplash = doc['active'])
               └→ _getSplashscreenWidget()
                  └→ Affichage SplashscreenV1/V2/V3
                     └→ Future.delayed(2s)
                        └→ setState(_loading = false)
                           └→ Affichage HomePage

2. ADMIN CHANGE
   └→ Admin clique toggle
      └→ _setActiveSplashscreen(id)
         └→ Firestore.set('/config/splashscreen', {active: id})
            └→ setState(_activeSplash = id)
               └→ Rebuild avec nouveau badge
                  └→ showSuccessSnackBar()

3. NEXT APP START
   └→ Nouveau splashscreen affiché
```

---

**Avantages de cette architecture:**

✅ Séparation des responsabilités
✅ Facile à étendre (ajout de V4, V5...)
✅ Centralisé (une seule source de vérité)
✅ Sécurisé (règles Firestore)
✅ Réactif (updates en temps réel)
✅ Testable (composants isolés)
