# 🚀 Instructions de Déploiement Manuel

**Date:** 11 janvier 2026  
**Modification:** Mise à jour section "Comment ça marche ?"  
**Fichier modifié:** `lib/pages/home_page_v2_option2.dart`

---

## ✅ Fichiers modifiés à commit

- `lib/pages/home_page_v2_option2.dart` (section "Comment ça marche ?")
- `UPDATE_HOW_IT_WORKS.md` (documentation)
- `DEPLOY_INFO.txt` (info de déploiement)
- `deploy_quick.sh` (script de déploiement)
- `MANUAL_DEPLOY_INSTRUCTIONS.md` (ce fichier)

---

## 📝 Commandes à exécuter

### 1. Commit Git

```bash
cd /workspaces/presto_app

git add -A

git commit -m "feat: update 'How it works' section with improved 3-step user journey

- Replace old 2-step flow with comprehensive 3-step explanation
- Step 1: Vous avez besoin de quelqu'un (Describe service needs)
- Step 2: Vous publiez votre annonce (Broadcast to nearby providers)
- Step 3: Les prestataires vous contactent (Instant responses)
- More engaging and clearer user experience flow
- Better copy that emphasizes speed and simplicity

Files modified:
- lib/pages/home_page_v2_option2.dart (lines 243-259)

Status: ✅ Tested, no compilation errors"

git push origin main
```

### 2. Build Flutter Web

```bash
flutter clean
flutter pub get
flutter build web --release
```

**Résultat attendu:**
- Build complet dans `build/web/`
- Fichiers optimisés pour production
- Assets copiés correctement

### 3. Déploiement Firebase Hosting

```bash
# Option A: Hosting seulement
firebase deploy --only hosting

# Option B: Tout déployer (hosting + rules + functions si besoin)
firebase deploy
```

**Vérification:**
- Console: https://console.firebase.google.com/project/presto-app-74abe
- App live: https://presto-app-74abe.web.app
- GitHub Pages: https://stef25fwi.github.io/presto_app

### 4. Vérification post-déploiement

```bash
# Vérifier les logs
firebase functions:log --limit 20

# Tester l'app
# Ouvrir: https://presto-app-74abe.web.app
# Vérifier que la section "Comment ça marche ?" affiche bien les 3 nouvelles étapes
```

---

## 🔍 Checklist de Vérification

Avant de déployer:
- [ ] Compilation sans erreurs (`flutter analyze`)
- [ ] Build web réussi (`flutter build web --release`)
- [ ] Tests manuels de la page d'accueil
- [ ] Section "Comment ça marche ?" affiche bien 3 étapes

Après déploiement:
- [ ] App accessible sur Firebase Hosting
- [ ] Section "Comment ça marche ?" mise à jour visible
- [ ] Pas d'erreurs dans la console
- [ ] Performance correcte (Lighthouse > 90)

---

## 🐛 Dépannage

### Erreur de build
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Erreur Firebase CLI
```bash
npm install -g firebase-tools
firebase login
firebase use presto-app-74abe
```

### Cache problématique
```bash
# Nettoyer le cache Flutter
flutter clean
rm -rf build/

# Nettoyer le cache Firebase
firebase hosting:disable
firebase deploy --only hosting
```

---

## 📊 Résumé des Changements

### Ancien Contenu (2 étapes)
```
1. Je publie une offre
   → Les prestataires proches sont notifiés

3. Je choisis et je valide
```

### Nouveau Contenu (3 étapes complètes)
```
1. Vous avez besoin de quelqu'un
   → Un coup de main, un job urgent, un service précis ?
   → Expliquez simplement ce dont vous avez besoin.

2. Vous publiez votre annonce
   → En quelques secondes, votre annonce est diffusée
   → aux prestataires disponibles autour de vous.

3. Les prestataires vous contactent immédiatement
   → Les personnes intéressées reçoivent votre demande
   → instantanément et vous répondent dans la foulée.
   → Vous choisissez la personne qui vous convient.
```

---

## 🔗 Liens Utiles

- **Firebase Console:** https://console.firebase.google.com/project/presto-app-74abe
- **GitHub Repo:** https://github.com/stef25fwi/presto_app
- **App Production:** https://presto-app-74abe.web.app
- **GitHub Pages:** https://stef25fwi.github.io/presto_app

---

**Status:** 🟢 Prêt à déployer  
**Dernière mise à jour:** 11 janvier 2026
