# 🚀 Guide Rapide - Gestion des Splashscreens

## Ce qui a été créé

✅ **Page Admin de Gestion des Splashscreens**
- Localisation: `lib/pages/admin/splashscreen_management_page.dart`
- Accès: Espace Admin > Tuile "Splashscreen"
- 3 versions disponibles: V1, V2, V3

✅ **Intégration Admin**
- Nouvelle tuile dans l'Espace Admin
- Icône: 📚 photo_library_rounded
- Couleur: Bleu Presto

✅ **Sécurité Firestore**
- Règles ajoutées pour `/config/splashscreen`
- Lecture publique, écriture admin uniquement

✅ **Documentation**
- Guide complet: `SPLASHSCREEN_MANAGEMENT.md`
- Résumé: `SPLASHSCREEN_IMPLEMENTATION_SUMMARY.md`
- Exemples: `lib/widgets/splashscreen_implementation_example.dart`

## Comment utiliser

### 1. Accéder à la gestion (Administrateur)

```
Profil > Espace Admin > Tuile "Splashscreen"
```

### 2. Changer de splashscreen

- Activer le toggle de la version souhaitée
- Le changement est immédiat et sauvegardé automatiquement
- Un badge "Actif" indique la version courante

### 3. Voir le résultat

Le splashscreen sélectionné sera affiché au prochain démarrage de l'app (après implémentation des widgets).

## Prochaines étapes

### À faire pour finaliser

1. **Créer les widgets splashscreen**
   - Copier les exemples depuis `splashscreen_implementation_example.dart`
   - Créer: `splashscreen_v1.dart`, `splashscreen_v2.dart`, `splashscreen_v3.dart`
   - Les placer dans `lib/widgets/`

2. **Intégrer dans main.dart**
   ```dart
   import 'widgets/splashscreen_loader.dart';
   
   // Dans MyApp:
   home: SplashscreenLoader(
     onComplete: () => const HomePage(),
   ),
   ```

3. **Déployer les règles Firestore**
   ```bash
   firebase deploy --only firestore:rules
   ```

4. **Tester**
   - Lancer l'app
   - Aller dans l'admin
   - Changer de splashscreen
   - Redémarrer l'app
   - Vérifier que le bon splashscreen s'affiche

## Structure des fichiers

```
lib/
├── pages/
│   └── admin/
│       └── splashscreen_management_page.dart    [CRÉÉ ✅]
└── widgets/
    ├── splashscreen_implementation_example.dart [CRÉÉ ✅]
    ├── splashscreen_v1.dart                     [À CRÉER]
    ├── splashscreen_v2.dart                     [À CRÉER]
    ├── splashscreen_v3.dart                     [À CRÉER]
    └── splashscreen_loader.dart                 [À CRÉER]
```

## Notes importantes

⚠️ **Firestore**
- Collection: `/config/splashscreen`
- Champ: `active` (string: "v1", "v2" ou "v3")
- Créé automatiquement lors du premier changement

⚠️ **Permissions**
- Seuls les administrateurs peuvent modifier
- Document admin requis dans `/admins/{userId}`

⚠️ **Fallback**
- Si erreur de chargement: V1 utilisé par défaut
- Si document n'existe pas: V1 utilisé par défaut

## Dépannage

### Le bouton Splashscreen n'apparaît pas
- Vérifier que vous êtes admin
- Document requis: `/admins/{votre-uid}` avec `enabled: true`

### Changement non pris en compte
- Vérifier Firestore: `/config/splashscreen`
- Redémarrer complètement l'application
- Vérifier les logs pour erreurs

### Erreur de permission
- Déployer les règles Firestore
- Vérifier le statut admin

## Support

📖 Documentation complète: `SPLASHSCREEN_MANAGEMENT.md`
📊 Résumé détaillé: `SPLASHSCREEN_IMPLEMENTATION_SUMMARY.md`
💻 Exemples de code: `lib/widgets/splashscreen_implementation_example.dart`

---

**Statut actuel:** ✅ Interface admin prête
**Reste à faire:** Implémenter les widgets splashscreen dans l'app
