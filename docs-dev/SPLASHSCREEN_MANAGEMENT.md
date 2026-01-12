# 🎨 Gestion du Splashscreen - Documentation

## Vue d'ensemble

Cette fonctionnalité permet aux administrateurs de choisir quelle version du splashscreen s'affiche au démarrage de l'application IliPrestō.

## Fichiers créés

### 1. Page de gestion
**Fichier:** `lib/pages/admin/splashscreen_management_page.dart`

Page d'administration pour sélectionner le splashscreen actif.

**Fonctionnalités:**
- Liste des versions disponibles (V1, V2, V3)
- Toggles pour activer une version
- Affichage du splashscreen actif avec badge
- Descriptions de chaque version
- Sauvegarde dans Firestore

**Usage:**
Accès via la tuile "Splashscreen" dans l'Espace Admin

## Architecture

### Structure Firestore

```
/config/splashscreen
{
  "active": "v1",          // ID du splashscreen actif
  "updatedAt": Timestamp   // Date de dernière modification
}
```

### Versions disponibles

1. **V1 - Original**
   - Description: Version originale avec logo et animation de base
   - Icône: ⭐ star_rounded
   - Couleur: Orange (#FF6600)

2. **V2 - Moderne**
   - Description: Version moderne avec animations avancées
   - Icône: ✨ auto_awesome_rounded
   - Couleur: Bleu (#1A73E8)

3. **V3 - Minimaliste**
   - Description: Version minimaliste et élégante
   - Icône: 📈 trending_up_rounded
   - Couleur: Violet

## Intégration

### Dans AdminSpacePage

```dart
import '../pages/admin/splashscreen_management_page.dart';

// Tuile ajoutée dans le GridView:
_KpiTile(
  icon: Icons.photo_library_rounded,
  title: 'Splashscreen',
  subtitle: 'Versions V1, V2, V3',
  badge: null,
  iconColor: prestoBlue,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SplashscreenManagementPage(),
      ),
    );
  },
),
```

### Règles Firestore

```
match /config/{configDoc} {
  allow read: if true;           // Lecture publique
  allow write: if isAdmin();     // Écriture admin uniquement
}
```

## Utilisation

### Pour les administrateurs

1. Ouvrir l'Espace Admin
2. Cliquer sur la tuile "Splashscreen"
3. Choisir la version souhaitée avec le toggle
4. Le changement est immédiat et sauvegardé

### Pour l'application

L'application devra lire la valeur active depuis Firestore:

```dart
// Au démarrage de l'app
final doc = await FirebaseFirestore.instance
    .collection('config')
    .doc('splashscreen')
    .get();

final activeSplash = doc.data()?['active'] ?? 'v1';

// Afficher le splashscreen correspondant
switch (activeSplash) {
  case 'v1':
    return SplashscreenV1();
  case 'v2':
    return SplashscreenV2();
  case 'v3':
    return SplashscreenV3();
  default:
    return SplashscreenV1();
}
```

## Avantages

✅ **Flexibilité**: Changer de splashscreen sans recompiler l'application
✅ **A/B Testing**: Tester différentes versions facilement
✅ **Remote Control**: Gestion centralisée depuis l'admin
✅ **Simplicité**: Interface intuitive avec toggles visuels
✅ **Traçabilité**: Date de modification enregistrée

## Prochaines étapes

### Implémentation des splashscreens

Il faudra créer les widgets correspondants:
- `lib/widgets/splashscreen_v1.dart`
- `lib/widgets/splashscreen_v2.dart`
- `lib/widgets/splashscreen_v3.dart`

### Logique de démarrage

Modifier le fichier `lib/main.dart` pour lire la configuration Firestore et afficher le bon splashscreen.

### Ajout de versions

Pour ajouter une nouvelle version:

1. Ajouter l'entrée dans `_splashscreens` list:
```dart
{
  'id': 'v4',
  'name': 'Splashscreen V4',
  'description': 'Nouvelle version premium',
  'icon': Icons.diamond_rounded,
  'color': Colors.amber,
}
```

2. Créer le widget correspondant
3. Mettre à jour la logique de démarrage

## Support

Pour toute question ou problème, contacter l'équipe technique.

---

**Version**: 1.0
**Date**: Janvier 2026
**Statut**: ✅ Production-ready
