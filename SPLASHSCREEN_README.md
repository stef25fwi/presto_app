# 🎨 Système de Gestion des Splashscreens

## Vue d'ensemble rapide

Un système complet pour gérer dynamiquement les splashscreens de l'application IliPrestō depuis l'interface admin, avec 3 versions disponibles.

## 🚀 Démarrage Rapide

### 1. Initialiser Firestore

Créer le document `/config/splashscreen` dans Firebase Console :

```json
{
  "active": "v1",
  "updatedAt": [Timestamp actuel]
}
```

### 2. Accéder à l'Admin

```
App → Profil → Espace Admin → Tuile "Splashscreen"
```

### 3. Changer de Version

- Activer le toggle de V1, V2 ou V3
- Le changement prend effet au prochain lancement

## 📁 Fichiers Importants

| Fichier | Description |
|---------|-------------|
| `lib/pages/admin/splashscreen_management_page.dart` | Interface admin |
| `lib/widgets/splashscreen_v1.dart` | Splashscreen original (orange) |
| `lib/widgets/splashscreen_v2.dart` | Splashscreen moderne (bleu) |
| `lib/widgets/splashscreen_v3.dart` | Splashscreen minimaliste (violet) |
| `lib/widgets/splashscreen_loader.dart` | Gestionnaire dynamique |

## 📖 Documentation

- **[SPLASHSCREEN_FINAL_SUMMARY.md](SPLASHSCREEN_FINAL_SUMMARY.md)** - Résumé complet
- **[SPLASHSCREEN_MANAGEMENT.md](SPLASHSCREEN_MANAGEMENT.md)** - Guide détaillé
- **[SPLASHSCREEN_ARCHITECTURE.md](SPLASHSCREEN_ARCHITECTURE.md)** - Architecture technique
- **[SPLASHSCREEN_QUICKSTART.md](SPLASHSCREEN_QUICKSTART.md)** - Démarrage rapide

## ✅ Statut

**🟢 Production Ready** - Système complet et déployé

---

**Dernière mise à jour:** 12 Janvier 2026
