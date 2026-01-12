🚀 GUIDE DE DÉPLOIEMENT WEB
============================

Mise à jour de https://presto-app-74abe.web.app

## 📋 Commandes à Exécuter

### Option 1: Script Automatique (Recommandé)

```bash
chmod +x deploy_web_complete.sh
./deploy_web_complete.sh
```

### Option 2: Commandes Manuelles

```bash
# 1. Nettoyage
flutter clean

# 2. Dépendances
flutter pub get

# 3. Build web
flutter build web --release --base-href="/"

# 4. Déploiement Firebase
firebase deploy --only hosting

# 5. Règles Firestore (si pas fait)
firebase deploy --only firestore:rules
```

### Option 3: Script Existant

```bash
chmod +x build_and_deploy.sh
./build_and_deploy.sh
```

## ⏱️ Temps Estimé

- Clean + pub get: ~1-2 min
- Build web: ~3-5 min
- Deploy hosting: ~1-2 min
- **Total: ~5-10 minutes**

## ✅ Vérification Après Déploiement

1. **Ouvrir l'app:**
   https://presto-app-74abe.web.app

2. **Tester "Je consulte les offres":**
   - Naviguer vers "Je consulte"
   - Vérifier que les annonces se chargent
   - Tester les filtres

3. **Tester Splashscreen (Admin):**
   - Se connecter en admin
   - Profil > Espace Admin > Splashscreen
   - Vérifier les 3 versions (V1, V2, V3)

4. **Initialiser Config Splashscreen:**
   - Firebase Console > Firestore
   - Collection: `config`
   - Document: `splashscreen`
   - Champs:
     ```json
     {
       "active": "v1",
       "updatedAt": [Timestamp actuel]
     }
     ```

## 📦 Ce qui sera Déployé

### Modifications Incluses

✅ **Page "Je consulte"**
- Correction règles Firestore
- Support du champ `isActive`
- Les annonces se chargent maintenant

✅ **Système Splashscreen**
- 3 versions de splashscreen (V1, V2, V3)
- Interface admin pour changer de version
- Loader dynamique depuis Firestore

### Fichiers Déployés

- `build/web/` → Firebase Hosting
- `firestore.rules` → Règles Firestore
- Tous les nouveaux widgets et pages

## 🔍 Diagnostic en Cas de Problème

### Build échoue

```bash
# Nettoyer complètement
flutter clean
rm -rf build/
rm pubspec.lock

# Réinstaller
flutter pub get
flutter pub upgrade

# Rebuild
flutter build web --release
```

### Déploiement échoue

```bash
# Vérifier connexion Firebase
firebase login
firebase use presto-app-74abe

# Vérifier permissions
firebase projects:list

# Redéployer
firebase deploy --only hosting
```

### Les annonces ne se chargent pas

1. Vérifier que les règles sont déployées:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. Console Firebase > Firestore > Règles
   - Vérifier que `isPublicOffer()` contient:
   ```javascript
   || (resource.data.isActive == true)
   ```

### Splashscreen ne fonctionne pas

1. Créer le document `/config/splashscreen` dans Firestore
2. Vérifier que le document contient: `{ active: "v1" }`
3. Vider le cache du navigateur et recharger

## 📊 URLs Utiles

- **App Web:** https://presto-app-74abe.web.app
- **Console Firebase:** https://console.firebase.google.com/project/presto-app-74abe
- **Firestore:** https://console.firebase.google.com/project/presto-app-74abe/firestore
- **Hosting:** https://console.firebase.google.com/project/presto-app-74abe/hosting

## 🎯 Checklist Post-Déploiement

- [ ] App web accessible
- [ ] Page "Je consulte" charge les annonces
- [ ] Filtres fonctionnent
- [ ] Admin accessible
- [ ] Page Splashscreen admin visible
- [ ] Document `/config/splashscreen` créé
- [ ] Cache navigateur vidé
- [ ] Tests complets effectués

## 💡 Conseils

- **Cache:** Toujours vider le cache après déploiement
- **Incognito:** Tester en mode navigation privée
- **Console:** Ouvrir DevTools pour voir les erreurs
- **Logs:** Consulter les logs Firebase si problème

---

**Date:** 12 Janvier 2026
**Version:** Avec corrections Je consulte + Splashscreen
**Statut:** Prêt pour déploiement
