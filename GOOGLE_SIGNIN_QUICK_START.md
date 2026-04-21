# 🚀 Google Sign-In - Démarrage Rapide

**Problème**: La connexion Google ne fonctionne pas sur la page de profil  
**Solution**: Configuration manuelle de Firebase Console et Google Cloud Console

---

## ⚡ 3 Étapes Essentielles (15-20 minutes)

### 1️⃣ Firebase Console - Activer Google Sign-In
```
URL: https://console.firebase.google.com/project/presto-app-74abe/authentication

Actions:
  1. Cliquer "Sign-in method"
  2. Cliquer sur "Google"
  3. Basculer "Enable" → Bleu ✅
  4. "Save"
```

### 2️⃣ Firebase Console - Ajouter Domaines Autorisés
```
URL: https://console.firebase.google.com/project/presto-app-74abe/authentication/settings

Actions:
  1. Aller à "Authorized domains"
  2. Ajouter 3 domaines:
     • localhost
     • presto-app-74abe.web.app
     • presto-app-74abe.firebaseapp.com
```

### 3️⃣ Google Cloud Console - Configurer OAuth
```
URL: https://console.cloud.google.com/apis/credentials/consent?project=presto-app-74abe

Actions:
  1. Cliquer "EDIT APPLICATION"
  2. Remplir formulaire:
     - App name: "Prestō"
     - Support email: votre email
     - Developer contact: votre email
  3. Ajouter scopes:
     - email
     - profile
  4. "Save and Continue"
```

---

## ✅ Après Configuration

### Test Local
```bash
flutter run -d chrome
# Aller à "Mon compte" → Cliquer "Continuer avec Google" → Doit fonctionner!
```

### Test Production
```bash
flutter build web --release
firebase deploy --only hosting
# Tester sur https://presto-app-74abe.web.app
```

---

## 📚 Documentation Détaillée

Pour une configuration plus détaillée et dépannage:

- **[GOOGLE_LOGIN_SETUP_GUIDE.md](./GOOGLE_LOGIN_SETUP_GUIDE.md)** - Guide complet avec étapes détaillées
- **[FIREBASE_GOOGLE_CONFIG_CHECKLIST.md](./FIREBASE_GOOGLE_CONFIG_CHECKLIST.md)** - Checklist interactive
- **[verify_google_signin_config.sh](./verify_google_signin_config.sh)** - Script de vérification

---

## ❓ Questions Courantes

**Q: Combien de temps pour la propagation?**  
R: 5-10 minutes généralement

**Q: Popup bloquée, que faire?**  
R: C'est normal! Le code bascule automatiquement en redirect flow

**Q: Erreur "unauthorized-domain"?**  
R: Vérifier que le domaine est ajouté dans Firebase Console

**Q: Client ID incorrect?**  
R: Le Client ID dans web/index.html est correct, vérifier la configuration Google Cloud

---

## 🎯 État Actuel

✅ Code correctement implémenté
✅ Client ID Web configuré
✅ Firebase Options configurées  
❌ Firebase Console - À configurer (ÉTAPE 1-2)
❌ Google Cloud Console - À configurer (ÉTAPE 3)

Après les 3 étapes ci-dessus, tout fonctionnera! 🎉

---

**Dernière mise à jour**: 21 avril 2026
